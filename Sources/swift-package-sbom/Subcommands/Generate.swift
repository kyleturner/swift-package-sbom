import Foundation
import struct Foundation.URL
import CryptoKit

import ArgumentParser

import Basics
import PackageGraph
import TSCBasic
import Workspace

//import Git

import CycloneDX

import ArgumentParser

extension SwiftPackageSBOM {
    struct Generate: ParsableCommand {
        static var configuration = CommandConfiguration(
            abstract: "Generate a software bill of materials for a package at a path."
        )

        @Argument(help: "Location of the package")
        var packagePath: AbsolutePath

        mutating func run() throws {
            var bom = BillOfMaterials(version: 1)

            // Load package information
            let observability = ObservabilitySystem({ print("\($0): \($1)") })
            let workspace = try Workspace(forRootPackage: packagePath)

            let graph = try workspace.loadPackageGraph(rootPath: packagePath, observabilityScope: observability.topScope)

            // Detect license files
            var licenses: [License] = []
            do {
                for file in try FileManager.default.contentsOfDirectory(at: packagePath.asURL, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles]) {
                    guard file.lastPathComponent.localizedCaseInsensitiveContains("license"),
                          let text = try? String(contentsOf: file)
                    else { continue }

                    licenses.append(.license(name: file.lastPathComponent, text: text))
                }
            }

            // Record root package products as components
            for product in graph.reachableProducts {
                guard product.targets.allSatisfy(graph.isInRootPackages) else { continue }

                let classification: Component.Classification

                switch product.type {
                case .library:
                    classification = .library
                case .executable:
                    classification = .application
                case .test:
                    continue
                case .snippet:
                    continue
                case .plugin:
                    continue
                }

                var component = Component(id: product.name, classification: classification)
                component.licenses = licenses

                // If the package root has a Git repository, record the latest commit
//                if let head = repository?.head?.commit {
//                    var commit = CycloneDX.Commit(id: head.id.description)
//                    commit.author = IdentifiableAction(timestamp: head.author.time, name: head.author.name, email: head.author.email)
//                    commit.committer = IdentifiableAction(timestamp: head.committer.time, name: head.committer.name, email: head.committer.email)
//                    commit.message = head.message?.trimmingCharacters(in: .whitespacesAndNewlines)
//                    component.pedigree = Pedigree(commits: [commit])
//                }

                // Record each source file in the component
                do {
                    for path in Set(product.targets.flatMap { $0.sources.paths }) {
                        var file = Component(id: path.relative(to: packagePath).description, classification: .file)
                        file.mimeType = path.preferredMIMEType
                        file.hashes = try Hash.standardHashes(forFileAt: path)
                        component.components.append(file)
                    }
                }

                bom.components.append(component)
            }

            // Record dependency packages as components
            for dependency in graph.requiredDependencies {
                if case .remoteSourceControl(let sourceURL) = dependency.kind {
                    var component = Component(id: dependency.identity.description, classification: .library)

                    do {
                        let reference = ExternalReference(kind: .vcs, url: sourceURL)
                        component.externalReferences.append(reference)
                    }

                    bom.components.append(component)
                }
            }

            // Record dependencies
            for package in graph.inputPackages where !graph.isRootPackage(package) {
                bom.dependencies.append(Dependency(package))
            }

            // Print JSON representation of SBoM
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted]
            encoder.dateEncodingStrategy = .iso8601
            let data = try encoder.encode(bom)
            let json = String(data: data, encoding: .utf8)!
            print(json)
        }
    }
}

fileprivate extension Dependency {
    init(_ package: ResolvedPackage) {
        self.init(reference: package.identity.description,
                  dependsOn: package.dependencies.map(Dependency.init))
    }
}
