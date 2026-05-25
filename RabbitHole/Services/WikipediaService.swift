import Foundation

struct WikipediaArticle {
    let pageID: Int
    let title: String
    let normalizedTitle: String
    let summary: String             // Intro text
    let links: [String]            // Outgoing Wikipedia links
    let categories: [String]
    let wikidataID: String?
}

struct WikipediaSearchResult {
    let title: String
    let description: String
    let thumbnail: String?
}

actor WikipediaService {
    private let baseURL = "https://en.wikipedia.org/api/rest_v1"
    private let apiURL = "https://en.wikipedia.org/w/api.php"
    private let session: URLSession

    init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 15
        self.session = URLSession(configuration: config)
    }

    func fetchArticle(title: String) async throws -> WikipediaArticle {
        async let summary = fetchSummary(title: title)
        async let links = fetchLinks(title: title)
        let (articleSummary, articleLinks) = try await (summary, links)

        return WikipediaArticle(
            pageID: articleSummary.pageID,
            title: articleSummary.title,
            normalizedTitle: articleSummary.normalizedTitle,
            summary: articleSummary.extract,
            links: articleLinks,
            categories: articleSummary.categories,
            wikidataID: articleSummary.wikidataID
        )
    }

    func search(query: String) async throws -> [WikipediaSearchResult] {
        var components = URLComponents(string: "https://api.wikimedia.org/core/v1/wikipedia/en/search/title")!
        components.queryItems = [
            URLQueryItem(name: "q", value: query),
            URLQueryItem(name: "limit", value: "8")
        ]
        let (data, _) = try await session.data(from: components.url!)
        let decoded = try JSONDecoder().decode(WikipediaSearchResponse.self, from: data)
        return decoded.pages.map {
            WikipediaSearchResult(
                title: $0.title,
                description: $0.description ?? "",
                thumbnail: $0.thumbnail?.url
            )
        }
    }

    private func fetchSummary(title: String) async throws -> WikipediaSummaryResponse {
        let encoded = title.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? title
        let url = URL(string: "\(baseURL)/page/summary/\(encoded)")!
        let (data, _) = try await session.data(from: url)
        return try JSONDecoder().decode(WikipediaSummaryResponse.self, from: data)
    }

    private func fetchLinks(title: String) async throws -> [String] {
        var components = URLComponents(string: apiURL)!
        components.queryItems = [
            URLQueryItem(name: "action", value: "query"),
            URLQueryItem(name: "titles", value: title),
            URLQueryItem(name: "prop", value: "links"),
            URLQueryItem(name: "pllimit", value: "100"),
            URLQueryItem(name: "plnamespace", value: "0"),
            URLQueryItem(name: "format", value: "json"),
            URLQueryItem(name: "formatversion", value: "2")
        ]
        let (data, _) = try await session.data(from: components.url!)
        let decoded = try JSONDecoder().decode(WikipediaLinksResponse.self, from: data)
        return decoded.query.pages.first?.links?.map(\.title) ?? []
    }
}

// MARK: - Response Models

private struct WikipediaSummaryResponse: Decodable {
    let pageID: Int
    let title: String
    let normalizedTitle: String
    let extract: String
    let categories: [String]
    let wikidataID: String?

    enum CodingKeys: String, CodingKey {
        case pageID = "pageid"
        case title
        case normalizedTitle = "displaytitle"
        case extract
        case wikidataID = "wikibase_item"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        pageID = try container.decodeIfPresent(Int.self, forKey: .pageID) ?? 0
        title = try container.decode(String.self, forKey: .title)
        normalizedTitle = try container.decodeIfPresent(String.self, forKey: .normalizedTitle) ?? title
        extract = try container.decodeIfPresent(String.self, forKey: .extract) ?? ""
        wikidataID = try container.decodeIfPresent(String.self, forKey: .wikidataID)
        categories = []
    }
}

private struct WikipediaSearchResponse: Decodable {
    let pages: [SearchPage]

    struct SearchPage: Decodable {
        let title: String
        let description: String?
        let thumbnail: Thumbnail?

        struct Thumbnail: Decodable {
            let url: String
        }
    }
}

private struct WikipediaLinksResponse: Decodable {
    let query: Query

    struct Query: Decodable {
        let pages: [Page]

        struct Page: Decodable {
            let links: [Link]?

            struct Link: Decodable {
                let title: String
            }
        }
    }
}
