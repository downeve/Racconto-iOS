import Foundation
import SwiftUI

struct Note: Codable, Identifiable {
    let id: String
    let projectId: String
    var content: String
    var noteType: String?
    var isPinned: Bool
    var photoId: String?
    var createdAt: Date
    var updatedAt: Date
    var deletedAt: Date?
}

struct NoteCreateRequest: Encodable {
    var projectId: String
    var content: String
    var noteType: String?
    var isPinned: Bool?
    var photoId: String?
}

struct NoteUpdateRequest: Encodable {
    var content: String?
    var noteType: String?
    var isPinned: Bool?
}

// MARK: - Note 카테고리 타입

struct NoteTypeInfo {
    let value: String
    let label: String
    let color: Color
    let dotColor: Color
}

let noteTypeList: [NoteTypeInfo] = [
    NoteTypeInfo(value: "memo",     label: "작업메모", color: Color(.systemGray5),                    dotColor: Color(.systemGray3)),
    NoteTypeInfo(value: "concept",  label: "컨셉",    color: Color(.systemBlue).opacity(0.12),       dotColor: .blue),
    NoteTypeInfo(value: "research", label: "리서치",  color: Color(.systemGreen).opacity(0.12),      dotColor: .green),
    NoteTypeInfo(value: "client",   label: "고객",    color: Color(.systemOrange).opacity(0.12),     dotColor: .orange),
]

func noteTypeInfo(for value: String?) -> NoteTypeInfo {
    noteTypeList.first(where: { $0.value == value }) ?? noteTypeList[0]
}
