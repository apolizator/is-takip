//
//  KonumSecici.swift
//  Afelay
//
//  Ürün eklerken konumu adım adım seçme akışı:
//  önce "var olan kategori mi / yeni kategori mi", sonra ana başlıklardan
//  başlayarak istenildiği kadar derine inme, istenilen yerde yeni başlık açma.
//

import SwiftUI

nonisolated struct KonumAdimi: Hashable {
    let id: UUID?
}

nonisolated struct KonumSecimi: Identifiable, Hashable {
    let id = UUID()
    let kategoriId: UUID?
}

// MARK: - Akış (sheet olarak açılır)

struct KonumAkisi: View {
    let vm: DepoVM
    var baslangic: UUID? = nil
    var baslik: String = "Konum Seç"
    var aciklama: String = "Bu ürün nereye eklensin?"
    var onSec: (UUID?) -> Void

    @Environment(\.dismiss) private var kapat
    @State private var yol: [KonumAdimi] = []
    @State private var yeniModu = false

    var body: some View {
        NavigationStack(path: $yol) {
            List {
                Section {
                    Text(aciklama)
                        .font(.headline)
                        .padding(.vertical, 2)
                }

                Section {
                    Button {
                        yeniModu = false
                        yol = [KonumAdimi(id: nil)]
                    } label: {
                        secenek("Var olan kategoriye ekle",
                                "Ana başlıklardan başla, tek tek dallara in.",
                                "folder.fill", .accentColor)
                    }
                    Button {
                        yeniModu = true
                        yol = [KonumAdimi(id: nil)]
                    } label: {
                        secenek("Yeni kategori açarak ekle",
                                "İstediğin derinlikte yeni başlık aç; iç içe de olabilir.",
                                "folder.badge.plus", .green)
                    }
                }

                if baslangic != nil {
                    Section("Kısayol") {
                        Button { sec(baslangic) } label: {
                            secenek("Doğrudan buraya ekle", vm.yol(baslangic),
                                    "arrow.down.to.line", .orange)
                        }
                    }
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle(baslik)
            .navigationBarTitleDisplayMode(.inline)
            .navigationDestination(for: KonumAdimi.self) { adim in
                KonumSeviyesi(vm: vm, kategoriId: adim.id, yeniVurgu: yeniModu,
                              yol: $yol, sec: sec)
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("İptal") { kapat() } }
            }
        }
    }

    private func sec(_ id: UUID?) {
        onSec(id)
        kapat()
    }

    private func secenek(_ baslik: String, _ alt: String, _ simge: String, _ renk: Color) -> some View {
        HStack(spacing: 12) {
            Image(systemName: simge)
                .font(.title3)
                .foregroundStyle(renk)
                .frame(width: 30)
            VStack(alignment: .leading, spacing: 2) {
                Text(baslik).font(.body).foregroundStyle(Color.primary)
                Text(alt).font(.caption2).foregroundStyle(Color.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer()
            Image(systemName: "chevron.right").font(.caption).foregroundStyle(Color.secondary)
        }
        .padding(.vertical, 2)
    }
}

// MARK: - Tek seviye

struct KonumSeviyesi: View {
    let vm: DepoVM
    let kategoriId: UUID?
    var yeniVurgu: Bool
    @Binding var yol: [KonumAdimi]
    var sec: (UUID?) -> Void

    @State private var yeniGoster = false
    @State private var yeniAd = ""

    var body: some View {
        let altlar = vm.altKategoriler(kategoriId)
        let o = vm.ozet(kategoriId)

        List {
            Section {
                VStack(alignment: .leading, spacing: 3) {
                    Text(vm.yol(kategoriId)).font(.subheadline).bold()
                    Text("\(o.adet) adet • \(o.urunSayisi) çeşit • \(altlar.count) alt başlık")
                        .font(.caption2).foregroundStyle(.secondary)
                }
                Button { sec(kategoriId) } label: {
                    Label("Bu konuma ekle", systemImage: "checkmark.circle.fill")
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 6)
                }
                .buttonStyle(.borderedProminent)
                .listRowInsets(EdgeInsets(top: 8, leading: 12, bottom: 8, trailing: 12))
            }

            if yeniVurgu { yeniBolum }

            if altlar.isEmpty {
                Section {
                    Text("Burada alt başlık yok. Ya bu konuma ekle ya da yeni bir başlık aç.")
                        .font(.caption).foregroundStyle(.secondary)
                }
            } else {
                Section("İçine gir") {
                    ForEach(altlar) { k in
                        NavigationLink(value: KonumAdimi(id: k.id)) {
                            KonumSatiri(vm: vm, kategori: k)
                        }
                    }
                }
            }

            if !yeniVurgu { yeniBolum }
        }
        .listStyle(.insetGrouped)
        .navigationTitle(vm.kategori(kategoriId)?.isim ?? "Ana Depo")
        .navigationBarTitleDisplayMode(.inline)
        .alert("Yeni başlık", isPresented: $yeniGoster) {
            TextField("Örn: Samsung", text: $yeniAd)
            Button("Oluştur") { olustur() }
            Button("Vazgeç", role: .cancel) { yeniAd = "" }
        } message: {
            Text("\(vm.yol(kategoriId)) altına açılacak.")
        }
    }

    @ViewBuilder private var yeniBolum: some View {
        Section {
            Button { yeniAd = ""; yeniGoster = true } label: {
                Label("Yeni alt başlık aç", systemImage: "folder.badge.plus")
                    .foregroundStyle(.green)
            }
        } footer: {
            Text("Açınca otomatik içine girer; istersen onun da altına bir tane daha açarsın.")
        }
    }

    private func olustur() {
        let ad = yeniAd
        yeniAd = ""
        if let yeni = vm.kategoriEkle(isim: ad, ustId: kategoriId) {
            yol.append(KonumAdimi(id: yeni))
        }
    }
}

// MARK: - Seçici satırı

struct KonumSatiri: View {
    let vm: DepoVM
    let kategori: Kategori

    var body: some View {
        let o = vm.ozet(kategori.id)
        let alt = vm.altKategoriler(kategori.id).count

        HStack(spacing: 10) {
            KucukResim(ad: kategori.resimAdi, boyut: 34, simge: "folder.fill", simgeRengi: .accentColor)
            VStack(alignment: .leading, spacing: 2) {
                Text(kategori.isim)
                Text(alt > 0 ? "\(alt) alt başlık • \(o.urunSayisi) çeşit" : "\(o.urunSayisi) çeşit ürün")
                    .font(.caption2).foregroundStyle(.secondary)
            }
            Spacer(minLength: 6)
            VStack(alignment: .trailing, spacing: 0) {
                Text("\(o.adet)").font(.subheadline).bold().foregroundStyle(.tint)
                Text("adet").font(.caption2).foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 2)
    }
}

// MARK: - Form içinde kullanılan konum satırı

struct KonumSecSatiri: View {
    let vm: DepoVM
    @Binding var kategoriId: UUID?
    var baslik: String = "Kategori"

    @State private var akisGoster = false

    var body: some View {
        Button { akisGoster = true } label: {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(baslik).foregroundStyle(Color.primary)
                    Text(vm.yol(kategoriId)).font(.caption).foregroundStyle(Color.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer()
                Image(systemName: "chevron.right").font(.caption).foregroundStyle(Color.secondary)
            }
        }
        .sheet(isPresented: $akisGoster) {
            KonumAkisi(vm: vm, baslangic: kategoriId,
                       baslik: "Konum Değiştir",
                       aciklama: "Bu ürün hangi kategoride dursun?") { secilen in
                kategoriId = secilen
            }
        }
    }
}
