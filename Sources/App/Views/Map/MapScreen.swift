import CoreLocation
import MapKit
import SwiftData
import SwiftUI

struct MapScreen: View {
    @EnvironmentObject private var session: AppSession
    @Query private var pins: [LocationPin]

    @State private var camera: MapCameraPosition = .automatic
    @State private var showAdd: Bool = false
    @State private var selected: LocationPin? = nil

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottomTrailing) {
                MapContentLayer(pins: pins, camera: $camera, selected: $selected)
                Button {
                    showAdd = true
                } label: {
                    Image(systemName: "plus")
                        .font(.headline)
                        .padding(14)
                        .background(Theme.accent, in: Circle())
                        .foregroundStyle(.white)
                        .shadow(color: .black.opacity(0.15), radius: 6, x: 0, y: 2)
                }
                .padding(20)
            }
            .navigationTitle("世界足迹")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Text("\(pins.count) 个坐标")
                        .font(.caption)
                        .foregroundStyle(Theme.textSecondary)
                }
            }
            .sheet(isPresented: $showAdd) {
                LocationEditorView { name, lat, lng, note, tags in
                    _ = session.repo.addLocation(name: name, lat: lat, lng: lng, note: note, tags: tags)
                    session.didMutateData()
                }
            }
            .sheet(item: $selected) { pin in
                LocationDetailView(pin: pin)
            }
        }
    }
}

/// 地图后端切换：默认系统 MapKit（零三方依赖、免 Key）；
/// Info.plist 里 EO_MAP_BACKEND = amap 且本地已集成高德 SDK 时自动切到 AMapMapView。
private struct MapContentLayer: View {
    let pins: [LocationPin]
    @Binding var camera: MapCameraPosition
    @Binding var selected: LocationPin?

    var body: some View {
        #if canImport(MAMapKit)
        if MapBackendResolver.useAMap {
            AMapMapView(pins: pins)
        } else {
            MapKitFallback(pins: pins, camera: $camera, selected: $selected)
        }
        #else
        MapKitFallback(pins: pins, camera: $camera, selected: $selected)
        #endif
    }
}

private struct MapKitFallback: View {
    let pins: [LocationPin]
    @Binding var camera: MapCameraPosition
    @Binding var selected: LocationPin?

    var body: some View {
        Group {
            if pins.isEmpty {
                EmptyStateView(emoji: "🗺️", title: "还没有足迹",
                               subtitle: "右下角加号记录第一个去过的地方")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                Map(position: $camera) {
                    ForEach(pins, id: \.persistentModelID) { pin in
                        Marker(pin.name.isEmpty ? "未命名" : pin.name,
                               systemImage: "mappin.circle.fill",
                               coordinate: CLLocationCoordinate2D(latitude: pin.lat, longitude: pin.lng))
                            .tint(Theme.accent)
                    }
                }
                .mapStyle(.standard)
            }
        }
    }
}

enum MapBackendResolver {
    static var useAMap: Bool {
        let backend = Bundle.main.object(forInfoDictionaryKey: "EO_MAP_BACKEND") as? String ?? "mapkit"
        return backend.lowercased() == "amap"
    }

    /// 高德 Key 只从 Info.plist 读取（由本地 Secrets.local.xcconfig 注入），仓库内无明文
    static var amapKey: String {
        (Bundle.main.object(forInfoDictionaryKey: "AMapKey") as? String ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

// MARK: - 新增足迹

struct LocationEditorView: View {
    @Environment(\.dismiss) private var dismiss
    var onCreate: (String, Double, Double, String?, [String]) -> Void

    @State private var name: String = ""
    @State private var latText: String = ""
    @State private var lngText: String = ""
    @State private var note: String = ""
    @State private var tagsText: String = ""
    @State private var isLocating: Bool = false
    @State private var hint: String = ""

    private let fetcher = LocationFetcher()

    var body: some View {
        NavigationStack {
            Form {
                Section("地点") {
                    TextField("名称", text: $name)
                    HStack {
                        TextField("纬度", text: $latText)
                        TextField("经度", text: $lngText)
                    }
                    Button {
                        locateMe()
                    } label: {
                        HStack {
                            Image(systemName: "location")
                            Text(isLocating ? "定位中…" : "使用当前位置")
                        }
                    }
                    if !hint.isEmpty {
                        Text(hint).font(.caption).foregroundStyle(Theme.textMuted)
                    }
                }
                Section("补充") {
                    TextField("备注（可选）", text: $note, axis: .vertical)
                    TextField("标签，逗号分隔", text: $tagsText)
                }
            }
            .navigationTitle("新增足迹")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("取消") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") {
                        guard let lat = Double(latText.trimmingCharacters(in: .whitespaces)),
                              let lng = Double(lngText.trimmingCharacters(in: .whitespaces)) else {
                            hint = "请填写合法的经纬度"
                            return
                        }
                        let title = name.trimmingCharacters(in: .whitespacesAndNewlines)
                        guard !title.isEmpty else {
                            hint = "请填写地点名称"
                            return
                        }
                        let tags = tagsText.split(separator: ",").map { String($0).trimmingCharacters(in: .whitespaces) }
                            .filter { !$0.isEmpty }
                        let cleaned = note.trimmingCharacters(in: .whitespacesAndNewlines)
                        onCreate(title, lat, lng, cleaned.isEmpty ? nil : cleaned, tags)
                        dismiss()
                    }
                }
            }
        }
    }

    private func locateMe() {
        isLocating = true
        hint = ""
        fetcher.request { result in
            isLocating = false
            switch result {
            case .success(let coordinate):
                latText = String(format: "%.6f", coordinate.latitude)
                lngText = String(format: "%.6f", coordinate.longitude)
            case .failure(let error):
                hint = error.localizedDescription
            }
        }
    }
}

struct LocationDetailView: View {
    @EnvironmentObject private var session: AppSession
    @Environment(\.dismiss) private var dismiss
    let pin: LocationPin

    var body: some View {
        NavigationStack {
            List {
                Section("地点") { Text(pin.name) }
                Section("坐标") {
                    Text("纬度 \(String(format: "%.6f", pin.lat))")
                    Text("经度 \(String(format: "%.6f", pin.lng))")
                }
                if let note = pin.note?.nonEmpty {
                    Section("备注") { Text(note) }
                }
                if !pin.tags.isEmpty {
                    Section("标签") { Text(pin.tags.joined(separator: "、")) }
                }
                Section {
                    Button(role: .destructive) {
                        session.repo.delete(pin)
                        session.didMutateData()
                        dismiss()
                    } label: { Text("删除这条足迹") }
                }
            }
            .navigationTitle("足迹详情")
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("关闭") { dismiss() } } }
        }
    }
}

// MARK: - 定位

final class LocationFetcher: NSObject, CLLocationManagerDelegate {
    private let manager = CLLocationManager()
    private var continuation: ((Result<CLLocationCoordinate2D, Error>) -> Void)?

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyHundredMeters
    }

    func request(_ completion: @escaping (Result<CLLocationCoordinate2D, Error>) -> Void) {
        continuation = completion
        manager.requestWhenInUseAuthorization()
        manager.requestLocation()
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.first else { return }
        continuation?(.success(location.coordinate))
        continuation = nil
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        continuation?(.failure(error))
        continuation = nil
    }
}
