import Foundation

public enum ModuleID: String, CaseIterable, Codable {
    case cpu = "CPU", memory = "RAM", sensors = "Sensors", network = "Network"
}
