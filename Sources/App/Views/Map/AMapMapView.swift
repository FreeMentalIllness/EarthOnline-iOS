#if canImport(MAMapKit)
// 高德地图 iOS SDK 适配层。
//
// 集成前提（官方 SDK 目前只有 .framework / CocoaPods 分发，不提供官方 SwiftPM 源）：
//   1. 从 lbs.amap.com 下载 AMapFoundationKit + MAMapKit 并加入工程（或使用 CocoaPods 引入）；
//   2. AMapFoundationKit 的 header 需通过桥接头文件暴露给 Swift；
//   3. Info.plist 的 EO_MAP_BACKEND 改成 amap，AMapKey 由本地 Secrets.local.xcconfig 注入。
// 未集成 SDK 时本文件整体不参与编译，CI 与默认构建走系统 MapKit，保证随时可出包。

import Foundation
import SwiftUI
import SwiftData
import MAMapKit
import AMapFoundationKit

struct AMapMapView: UIViewRepresentable {
    let pins: [LocationPin]

    func makeUIView(context: Context) -> MAMapView {
        // 与 Android 端同序：先声明合规，再建地图，否则白屏
        let key = MapBackendResolver.amapKey
        if !key.isEmpty { AMapServices.shared().apiKey = key }
        MAMapView.updatePrivacyShow(.didShow, privacyInfo: .didContain)
        MAMapView.updatePrivacyAgree(.didAgree)
        return MAMapView(frame: .zero)
    }

    func updateUIView(_ mapView: MAMapView, context: Context) {
        mapView.removeAnnotations(mapView.annotations ?? [])
        let annotations = pins.map { pin -> MAPointAnnotation in
            let annotation = MAPointAnnotation()
            annotation.coordinate = CLLocationCoordinate2D(latitude: pin.lat, longitude: pin.lng)
            annotation.title = pin.name
            return annotation
        }
        mapView.addAnnotations(annotations)
        if let first = pins.first {
            mapView.setCenter(CLLocationCoordinate2D(latitude: first.lat, longitude: first.lng), animated: false)
        }
    }
}
#endif
