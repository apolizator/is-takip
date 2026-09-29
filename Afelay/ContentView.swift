//
//  ContentView.swift
//  Afelay
//

import SwiftUI
import UIKit

struct ContentView: View {
    @State private var vm = DepoVM()
    @Environment(\.scenePhase) private var asama

    var body: some View {
        TabView {
            Tab("Depo", systemImage: "shippingbox.fill") {
                DepoSekmesi(vm: vm)
            }
            Tab("Al", systemImage: "cart.badge.plus") {
                HizliAlEkrani(vm: vm)
            }
            Tab("Sat", systemImage: "tag.fill") {
                HizliSatEkrani(vm: vm)
            }
            Tab("Görev", systemImage: "checklist") {
                GorevEkrani(vm: vm)
            }
            Tab("Bilanço", systemImage: "chart.bar.fill") {
                BilancoEkrani(vm: vm)
            }
        }
        .onChange(of: asama) { _, yeni in
            // Uygulama arka plana alınırken bekleyen yazmaları diske bas.
            // Ana thread bloklanmasın diye arka plan görevi olarak yapılır.
            guard yeni != .active else { return }
            let gorevId = UIApplication.shared.beginBackgroundTask(withName: "AfelayKaydet")
            Depolama.shared.hemenKaydet {
                Task { @MainActor in
                    if gorevId != .invalid { UIApplication.shared.endBackgroundTask(gorevId) }
                }
            }
        }
    }
}

#Preview {
    ContentView()
}
