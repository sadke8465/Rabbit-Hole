import Foundation

struct WikidataRelationship {
    let targetTitle: String
    let relationshipType: String    // e.g. "influenced_by", "inspired", "follows"
    let targetWikidataID: String
}

actor WikidataService {
    private let sparqlURL = "https://query.wikidata.org/sparql"
    private let session: URLSession

    // Relationship properties that signal interesting intellectual connections
    private let interestingProperties = [
        "P737": "influenced_by",
        "P influence": "influenced",
        "P941": "inspired_by",
        "P144": "based_on",
        "P155": "follows",
        "P156": "followed_by",
        "P921": "main_subject",
        "P1889": "different_from"
    ]

    init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 20
        config.httpAdditionalHeaders = [
            "Accept": "application/sparql-results+json",
            "User-Agent": "RabbitHole/1.0 (iOS)"
        ]
        self.session = URLSession(configuration: config)
    }

    func fetchRelationships(wikidataID: String) async throws -> [WikidataRelationship] {
        let propertyList = interestingProperties.keys
            .map { "wdt:\($0)" }
            .joined(separator: "|")

        let query = """
        SELECT ?item ?itemLabel ?prop WHERE {
          wd:\(wikidataID) (\(propertyList)) ?item .
          ?item schema:isPartOf <https://en.wikipedia.org/> .
          ?item schema:name ?itemLabel .
          FILTER(LANG(?itemLabel) = "en")
        }
        LIMIT 20
        """

        var components = URLComponents(string: sparqlURL)!
        components.queryItems = [URLQueryItem(name: "query", value: query)]
        var request = URLRequest(url: components.url!)
        request.setValue("application/sparql-results+json", forHTTPHeaderField: "Accept")

        let (data, _) = try await session.data(for: request)
        let decoded = try JSONDecoder().decode(SPARQLResponse.self, from: data)

        return decoded.results.bindings.compactMap { binding in
            guard let label = binding.itemLabel?.value,
                  let itemID = binding.item?.value.components(separatedBy: "/").last else { return nil }
            return WikidataRelationship(
                targetTitle: label,
                relationshipType: binding.prop?.value ?? "related",
                targetWikidataID: itemID
            )
        }
    }
}

// MARK: - SPARQL Response Models

private struct SPARQLResponse: Decodable {
    let results: Results

    struct Results: Decodable {
        let bindings: [Binding]
    }

    struct Binding: Decodable {
        let item: Value?
        let itemLabel: Value?
        let prop: Value?
    }

    struct Value: Decodable {
        let value: String
    }
}
