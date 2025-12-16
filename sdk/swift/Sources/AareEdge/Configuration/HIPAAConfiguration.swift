// HIPAA Configuration
// Loads and manages HIPAA Safe Harbor rules configuration

import Foundation

/// HIPAA category information
public struct HIPAACategoryInfo: Codable {
    public let id: Int
    public let name: String
    public let description: String
    public let bioLabels: [String]
    public let examples: [String]
    public let prohibited: Bool
    public let notes: String?

    enum CodingKeys: String, CodingKey {
        case id, name, description, examples, prohibited, notes
        case bioLabels = "bio_labels"
    }
}

/// HIPAA rule definition
public struct HIPAARule {
    public let id: String
    public let name: String
    public let description: String
    public let categories: [String]
    public let prohibitionType: String
    public let condition: String?

    public init(
        id: String,
        name: String,
        description: String,
        categories: [String],
        prohibitionType: String = "absolute",
        condition: String? = nil
    ) {
        self.id = id
        self.name = name
        self.description = description
        self.categories = categories
        self.prohibitionType = prohibitionType
        self.condition = condition
    }
}

/// HIPAA configuration loaded from hipaa-v1.json
public class HIPAAConfiguration {

    /// Singleton instance
    public static let shared = HIPAAConfiguration()

    public let version: String
    public let name: String
    public let configDescription: String
    public let categories: [HIPAACategoryInfo]
    public let labelList: [String]
    public let numLabels: Int
    public let datasetLabelRemap: [String: String]
    public let rules: [HIPAARule]

    /// Category lookup by name
    public let categoryMap: [String: HIPAACategoryInfo]

    /// Prohibited categories
    public let prohibitedCategories: Set<String>

    /// Label to ID mapping
    public let label2id: [String: Int]

    /// ID to label mapping
    public let id2label: [Int: String]

    private init() {
        // Load configuration from bundle
        guard let url = Bundle.module.url(forResource: "hipaa-v1", withExtension: "json", subdirectory: "Resources") ??
                        Bundle.main.url(forResource: "hipaa-v1", withExtension: "json") else {
            // Fallback to embedded configuration
            let config = Self.defaultConfiguration()
            self.version = config.version
            self.name = config.name
            self.configDescription = config.configDescription
            self.categories = config.categories
            self.labelList = config.labelList
            self.numLabels = config.numLabels
            self.datasetLabelRemap = config.datasetLabelRemap
            self.categoryMap = Dictionary(uniqueKeysWithValues: config.categories.map { ($0.name, $0) })
            self.prohibitedCategories = Set(config.categories.filter { $0.prohibited }.map { $0.name })
            self.label2id = Dictionary(uniqueKeysWithValues: config.labelList.enumerated().map { ($1, $0) })
            self.id2label = Dictionary(uniqueKeysWithValues: config.labelList.enumerated().map { ($0, $1) })
            self.rules = Self.buildRules(categories: config.categories)
            return
        }

        do {
            let data = try Data(contentsOf: url)
            let decoder = JSONDecoder()
            let config = try decoder.decode(ConfigFile.self, from: data)

            self.version = config.version
            self.name = config.name
            self.configDescription = config.description
            self.categories = config.categories
            self.labelList = config.labelList
            self.numLabels = config.numLabels
            self.datasetLabelRemap = config.datasetLabelRemap
            self.categoryMap = Dictionary(uniqueKeysWithValues: config.categories.map { ($0.name, $0) })
            self.prohibitedCategories = Set(config.categories.filter { $0.prohibited }.map { $0.name })
            self.label2id = Dictionary(uniqueKeysWithValues: config.labelList.enumerated().map { ($1, $0) })
            self.id2label = Dictionary(uniqueKeysWithValues: config.labelList.enumerated().map { ($0, $1) })
            self.rules = Self.buildRules(categories: config.categories)
        } catch {
            print("Warning: Failed to load hipaa-v1.json: \(error). Using default configuration.")
            let config = Self.defaultConfiguration()
            self.version = config.version
            self.name = config.name
            self.configDescription = config.configDescription
            self.categories = config.categories
            self.labelList = config.labelList
            self.numLabels = config.numLabels
            self.datasetLabelRemap = config.datasetLabelRemap
            self.categoryMap = Dictionary(uniqueKeysWithValues: config.categories.map { ($0.name, $0) })
            self.prohibitedCategories = Set(config.categories.filter { $0.prohibited }.map { $0.name })
            self.label2id = Dictionary(uniqueKeysWithValues: config.labelList.enumerated().map { ($1, $0) })
            self.id2label = Dictionary(uniqueKeysWithValues: config.labelList.enumerated().map { ($0, $1) })
            self.rules = Self.buildRules(categories: config.categories)
        }
    }

    /// Check if a category is prohibited
    public func isProhibited(_ category: String) -> Bool {
        prohibitedCategories.contains(category)
    }

    /// Get category information
    public func getCategoryInfo(_ name: String) -> HIPAACategoryInfo? {
        categoryMap[name]
    }

    /// Remap dataset label to HIPAA category
    public func remapLabel(_ originalLabel: String) -> String {
        if originalLabel == "O" {
            return "O"
        }

        // Handle BIO format
        let components = originalLabel.split(separator: "-", maxSplits: 1)
        let bioPrefix = components.count > 1 ? String(components[0]) : "B"
        let entityType = components.count > 1 ? String(components[1]) : originalLabel

        // Remap to HIPAA category
        let hipaaCategory = datasetLabelRemap[entityType] ?? "ANY_OTHER_UNIQUE_IDENTIFYING_NUMBER"

        return "\(bioPrefix)-\(hipaaCategory)"
    }

    /// Get rules for a specific category
    public func getRulesForCategory(_ category: String) -> [HIPAARule] {
        rules.filter { $0.categories.contains(category) }
    }

    // MARK: - Private Helpers

    private struct ConfigFile: Codable {
        let version: String
        let name: String
        let description: String
        let categories: [HIPAACategoryInfo]
        let labelList: [String]
        let numLabels: Int
        let datasetLabelRemap: [String: String]

        enum CodingKeys: String, CodingKey {
            case version, name, description, categories
            case labelList = "label_list"
            case numLabels = "num_labels"
            case datasetLabelRemap = "dataset_label_remap"
        }
    }

    private static func buildRules(categories: [HIPAACategoryInfo]) -> [HIPAARule] {
        var rules: [HIPAARule] = []

        // Build absolute prohibition rules (R1-R18)
        for (index, category) in categories.enumerated() {
            if category.prohibited {
                rules.append(HIPAARule(
                    id: "R\(index + 1)",
                    name: "Prohibition of \(category.name)",
                    description: category.description + " must be removed",
                    categories: [category.name],
                    prohibitionType: "absolute"
                ))
            }
        }

        // Conditional rules for extended verification
        rules.append(HIPAARule(
            id: "R19",
            name: "Age Over 89",
            description: "Ages over 89 must be aggregated to 90+",
            categories: ["DATES"],
            prohibitionType: "conditional",
            condition: "age > 89"
        ))

        rules.append(HIPAARule(
            id: "R20",
            name: "ZIP Code Population",
            description: "ZIP codes with population < 20,000 must be zeroed",
            categories: ["GEOGRAPHIC_SUBDIVISIONS"],
            prohibitionType: "conditional",
            condition: "zip_population < 20000"
        ))

        return rules
    }

    private static func defaultConfiguration() -> (
        version: String,
        name: String,
        configDescription: String,
        categories: [HIPAACategoryInfo],
        labelList: [String],
        numLabels: Int,
        datasetLabelRemap: [String: String]
    ) {
        // Minimal embedded configuration as fallback
        let categories = PHICategory.allCases.enumerated().map { index, category in
            HIPAACategoryInfo(
                id: index + 1,
                name: category.rawValue,
                description: category.description,
                bioLabels: ["B-\(category.rawValue)", "I-\(category.rawValue)"],
                examples: [],
                prohibited: true,
                notes: nil
            )
        }

        let labelList = ["O"] + categories.flatMap { $0.bioLabels }

        return (
            version: "1.0.0",
            name: "HIPAA Safe Harbor PHI Categories",
            configDescription: "18 categories of Protected Health Information identifiers",
            categories: categories,
            labelList: labelList,
            numLabels: labelList.count,
            datasetLabelRemap: [:]
        )
    }
}
