import PhotosUI
import SwiftData
import SwiftUI

/// 个人资料编辑（对应 profile 表，id 固定为 1 的单行）
struct ProfileEditView: View {
    @EnvironmentObject private var session: AppSession
    @Environment(\.dismiss) private var dismiss

    let profile: ProfileItem

    @State private var name: String = ""
    @State private var gender: String = ""
    @State private var avatarKey: String = ""
    @State private var country: String = ""
    @State private var province: String = ""
    @State private var signature: String = ""
    @State private var birthDate: Date = Date()
    @State private var hasBirthDate: Bool = false

    private let genders: [(String, String)] = [
        ("", "不填"),
        ("male", "男"),
        ("female", "女"),
        ("walmart", "沃尔玛购物袋"),
        ("helicopter", "直升机"),
        ("potato", "土豆")
    ]

    private let avatarKeys: [(String, String)] = [
        ("default", "🧑‍🚀"), ("earth", "🌏"), ("rocket", "🚀"),
        ("game", "🎮"), ("cat", "🐱"), ("leaf", "🍃"),
        ("music", "🎵"), ("star", "⭐️")
    ]

    var body: some View {
        NavigationStack {
            Form {
                Section("基本信息") {
                    TextField("昵称", text: $name)
                    Picker("性别", selection: $gender) {
                        ForEach(genders, id: \.0) { value, label in
                            Text(label).tag(value)
                        }
                    }
                    Toggle("设置出生日期", isOn: $hasBirthDate)
                    if hasBirthDate {
                        DatePicker("出生日期", selection: $birthDate,
                                   in: ...Date(), displayedComponents: .date)
                    }
                    TextField("国家/地区", text: $country)
                    TextField("省市", text: $province)
                    TextField("个性签名", text: $signature, axis: .vertical)
                }
                Section("头像") {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 12) {
                            ForEach(avatarKeys, id: \.0) { key, emoji in
                                Button {
                                    avatarKey = key
                                } label: {
                                    Text(emoji)
                                        .font(.largeTitle)
                                        .padding(6)
                                        .background(avatarKey == key ? Theme.accentSoft : Color.clear,
                                                    in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                                        .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous)
                                            .stroke(avatarKey == key ? Theme.accent : Color.clear, lineWidth: 1))
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                    PhotoPickerView(title: "上传自定义头像") { data in
                        if let relative = LocalFileStore.save(data, into: "avatar", filename: "avatar.jpg") {
                            profile.avatarPath = relative
                        }
                    }
                    if let path = profile.avatarPath?.nonEmpty {
                        Button(role: .destructive) {
                            LocalFileStore.delete(path)
                            profile.avatarPath = nil
                            session.repo.save()
                        } label: { Text("移除自定义头像") }
                    }
                }
                Section {
                    Button("保存") { save() }
                }
            }
            .navigationTitle("编辑资料")
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("关闭") { dismiss() } } }
            .onAppear(perform: load)
        }
    }

    private func load() {
        name = profile.name
        gender = profile.gender
        avatarKey = profile.avatarKey.isEmpty ? "default" : profile.avatarKey
        country = profile.country
        province = profile.province
        signature = profile.signature
        if let date = DateUtils.parseDay(profile.birthDate) {
            hasBirthDate = true
            birthDate = date
        } else {
            hasBirthDate = false
        }
    }

    private func save() {
        profile.name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        profile.gender = gender
        profile.avatarKey = avatarKey
        profile.country = country.trimmingCharacters(in: .whitespacesAndNewlines)
        profile.province = province.trimmingCharacters(in: .whitespacesAndNewlines)
        profile.signature = signature.trimmingCharacters(in: .whitespacesAndNewlines)
        profile.birthDate = hasBirthDate ? DateUtils.dayKeyFormatter.string(from: birthDate) : ""
        session.repo.save()
        session.didMutateData()
        dismiss()
    }
}
