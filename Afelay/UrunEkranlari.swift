//
//  UrunEkranlari.swift
//  Afelay
//
//  Ürün detayı, ürün formu, kategori formu ve ortak fotoğraf bölümü.
//

import SwiftUI
import PhotosUI

// MARK: - Fotoğraf bölümü (ürün ve kategori formlarında ortak)

struct FotografBolumu: View {
    @Binding var resimAdi: String?
    var simge: String = "shippingbox.fill"

    @State private var secim: PhotosPickerItem?
    @State private var yukleniyor = false

    var body: some View {
        Group {
            PhotosPicker(selection: $secim, matching: .images) {
                Label(resimAdi == nil ? "Fotoğraf ekle" : "Fotoğrafı değiştir", systemImage: "photo")
            }

            if yukleniyor {
                HStack(spacing: 8) {
                    ProgressView()
                    Text("Fotoğraf hazırlanıyor...").font(.caption).foregroundStyle(.secondary)
                }
            }

            if resimAdi != nil {
                BuyukResim(ad: resimAdi, yukseklik: 170, simge: simge)
                    .listRowInsets(EdgeInsets(top: 6, leading: 12, bottom: 6, trailing: 12))
                Button(role: .destructive) {
                    resimAdi = nil
                } label: {
                    Label("Fotoğrafı kaldır", systemImage: "trash")
                }
            }
        }
        .onChange(of: secim) { _, yeni in
            guard let yeni else { return }
            yukleniyor = true
            Task {
                defer { yukleniyor = false }
                guard let veri = try? await yeni.loadTransferable(type: Data.self) else { return }
                // Küçültme ve diske yazma ana thread dışında yapılır.
                let ad = await Task.detached(priority: .userInitiated) {
                    ResimDeposu.kaydet(veri)
                }.value
                if let ad { resimAdi = ad }
            }
        }
    }
}

// MARK: - Ürün detayı

struct UrunDetayEkrani: View {
    let vm: DepoVM
    let urunId: UUID

    @State private var duzenleGoster = false
    @State private var islemHedef: IslemHedef?

    var body: some View {
        if let u = vm.guncelUrun(urunId) {
            List {
                Section {
                    if u.resimAdi != nil {
                        BuyukResim(ad: u.resimAdi, yukseklik: 200)
                            .listRowInsets(EdgeInsets(top: 6, leading: 12, bottom: 6, trailing: 12))
                    }
                    HStack(spacing: 10) {
                        Button { islemHedef = IslemHedef(urun: u, tip: .alis) } label: {
                            Label("Al", systemImage: "cart.badge.plus")
                                .frame(maxWidth: .infinity).padding(.vertical, 8)
                        }
                        .buttonStyle(.borderedProminent).tint(.green)

                        Button { islemHedef = IslemHedef(urun: u, tip: .satis) } label: {
                            Label("Sat", systemImage: "tag")
                                .frame(maxWidth: .infinity).padding(.vertical, 8)
                        }
                        .buttonStyle(.borderedProminent).tint(.blue)
                        .disabled(u.miktar == 0)
                    }
                    .listRowInsets(EdgeInsets(top: 8, leading: 12, bottom: 8, trailing: 12))
                }

                Section("Bilgiler") {
                    bilgi("Stok", "\(u.miktar) adet")
                    bilgi("Alış", para(u.alisFiyati))
                    bilgi("Satış", para(u.satisFiyati))
                    bilgi("Birim kar", para(u.birimKar))
                    bilgi("Stok maliyeti", para(u.maliyet))
                    bilgi("Stok satış değeri", para(u.satisDegeri))
                    bilgi("Potansiyel kar", para(u.toplamKar))
                    bilgi("Konum", vm.yol(u.kategoriId))
                }

                if !u.aciklama.isEmpty {
                    Section("Notlar") { Text(u.aciklama) }
                }

                Section("Hareket Geçmişi") {
                    let hareket = vm.urunHareketleri(u.id)
                    if hareket.isEmpty {
                        Text("Henüz hareket yok.").foregroundStyle(.secondary)
                    }
                    ForEach(hareket) { h in
                        HStack(alignment: .top) {
                            VStack(alignment: .leading, spacing: 3) {
                                Text(h.tip.rawValue).bold()
                                    .foregroundStyle(h.tip == .alis ? .green : .blue)
                                Text("\(h.adet) adet • \(para(h.birimFiyat)) • \(h.kisi)")
                                    .font(.caption).foregroundStyle(.secondary)
                                Text(tarihSaatYazi(h.tarih))
                                    .font(.caption2).foregroundStyle(.secondary)
                            }
                            Spacer()
                            VStack(alignment: .trailing, spacing: 3) {
                                Text(para(h.tutar)).font(.caption).bold()
                                if h.tip == .satis {
                                    Text("kar \(para(h.kar))").font(.caption2).foregroundStyle(.green)
                                }
                            }
                        }
                        .padding(.vertical, 2)
                    }
                    .onDelete { idx in
                        let hareket = vm.urunHareketleri(u.id)
                        for i in idx where i < hareket.count { vm.islemSil(hareket[i].id) }
                    }
                    if !hareket.isEmpty {
                        Text("Bir hareketi silersen stok da geri alınır.")
                            .font(.caption2).foregroundStyle(.secondary)
                    }
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle(u.isim)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Düzenle") { duzenleGoster = true }
                }
            }
            .sheet(isPresented: $duzenleGoster) {
                UrunSheet(vm: vm, kategoriId: u.kategoriId, duzenle: u)
            }
            .sheet(item: $islemHedef) { h in
                IslemSheet(vm: vm, urun: h.urun, tip: h.tip)
            }
        } else {
            ContentUnavailableView("Ürün bulunamadı", systemImage: "questionmark.folder")
        }
    }

    private func bilgi(_ l: String, _ v: String) -> some View {
        HStack {
            Text(l).foregroundStyle(.secondary)
            Spacer()
            Text(v).bold().multilineTextAlignment(.trailing)
        }
    }
}

// MARK: - Ürün ekle / düzenle

struct UrunSheet: View {
    let vm: DepoVM
    var kategoriId: UUID?
    var duzenle: Urun? = nil

    @Environment(\.dismiss) private var kapat

    @State private var isim = ""
    @State private var aciklama = ""
    @State private var alis = ""
    @State private var satis = ""
    @State private var miktar = ""
    @State private var stok = ""
    @State private var kimden = ""
    @State private var secilenKategori: UUID?
    @State private var resimAdi: String?
    @State private var hazirlandi = false

    private var duzenleMi: Bool { duzenle != nil }
    private var gecerli: Bool { !isim.trimmingCharacters(in: .whitespaces).isEmpty }

    var body: some View {
        NavigationStack {
            Form {
                Section("Ürün") {
                    TextField("İsim", text: $isim)
                    TextField("Notlar", text: $aciklama, axis: .vertical)
                        .lineLimit(1...6)
                }

                Section("Fiyat") {
                    satir("Alış ₺", $alis, .decimalPad)
                    satir("Satış ₺", $satis, .decimalPad)
                    let birim = sayiCevir(satis) - sayiCevir(alis)
                    HStack {
                        Text("Birim kar")
                        Spacer()
                        Text(para(birim)).bold().foregroundStyle(birim >= 0 ? .green : .red)
                    }
                }

                Section(duzenleMi ? "Stok" : "Başlangıç Stoğu") {
                    if duzenleMi {
                        satir("Stok adedi", $stok, .numberPad)
                        Text("Buradan elle düzeltirsen alış/satış geçmişine kayıt düşmez.")
                            .font(.caption2).foregroundStyle(.secondary)
                    } else {
                        satir("Adet", $miktar, .numberPad)
                        TextField("Kimden alındı? (opsiyonel)", text: $kimden)
                    }
                }

                Section("Konum") {
                    KonumSecSatiri(vm: vm, kategoriId: $secilenKategori)
                }

                Section("Görsel") {
                    FotografBolumu(resimAdi: $resimAdi)
                }
            }
            .navigationTitle(duzenleMi ? "Ürünü Düzenle" : "Yeni Ürün")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("İptal") { kapat() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Kaydet") { kaydet() }.disabled(!gecerli)
                }
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Bitti") { kapatKlavye() }
                }
            }
            .onAppear(perform: hazirla)
        }
    }

    private func satir(_ baslik: String, _ deger: Binding<String>, _ tur: UIKeyboardType) -> some View {
        HStack {
            Text(baslik)
            Spacer()
            TextField("0", text: deger)
                .keyboardType(tur)
                .multilineTextAlignment(.trailing)
                .frame(maxWidth: 140)
        }
    }

    private func hazirla() {
        guard !hazirlandi else { return }
        hazirlandi = true
        if let u = duzenle {
            isim = u.isim
            aciklama = u.aciklama
            alis = kisaSayi(u.alisFiyati)
            satis = kisaSayi(u.satisFiyati)
            stok = String(u.miktar)
            secilenKategori = u.kategoriId
            resimAdi = u.resimAdi
        } else {
            secilenKategori = kategoriId
        }
    }

    private func kaydet() {
        let a = sayiCevir(alis)
        let s = sayiCevir(satis)
        if let u = duzenle {
            vm.urunGuncelle(id: u.id, isim: isim, aciklama: aciklama, alis: a, satis: s,
                            kategoriId: secilenKategori, resimAdi: resimAdi)
            let yeniStok = tamSayiCevir(stok)
            if yeniStok != u.miktar { vm.stokDuzelt(id: u.id, yeniMiktar: yeniStok) }
        } else {
            vm.urunEkle(isim: isim, aciklama: aciklama, alis: a, satis: s,
                        miktar: tamSayiCevir(miktar), kategoriId: secilenKategori,
                        resimAdi: resimAdi, kimden: kimden)
        }
        kapat()
    }
}

// MARK: - Kategori ekle / düzenle

struct KategoriSheet: View {
    let vm: DepoVM
    var ustId: UUID?
    var duzenle: Kategori? = nil

    @Environment(\.dismiss) private var kapat

    @State private var isim = ""
    @State private var not = ""
    @State private var resimAdi: String?
    @State private var hazirlandi = false

    private var duzenleMi: Bool { duzenle != nil }
    private var gecerli: Bool { !isim.trimmingCharacters(in: .whitespaces).isEmpty }

    var body: some View {
        NavigationStack {
            Form {
                Section("Konum") {
                    HStack {
                        Image(systemName: "arrow.turn.down.right").foregroundStyle(.secondary)
                        Text(vm.yol(ustId)).foregroundStyle(.secondary)
                    }
                }
                Section(duzenleMi ? "Ad" : "Yeni Başlık") {
                    TextField("Örn: Telefon / Samsung / S23", text: $isim)
                    TextField("Not (opsiyonel)", text: $not, axis: .vertical)
                        .lineLimit(1...6)
                }
                Section("Görsel") {
                    FotografBolumu(resimAdi: $resimAdi, simge: "folder.fill")
                }
            }
            .navigationTitle(duzenleMi ? "Kategoriyi Düzenle" : "Yeni Kategori")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("İptal") { kapat() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button(duzenleMi ? "Kaydet" : "Ekle") {
                        if let k = duzenle {
                            vm.kategoriGuncelle(id: k.id, isim: isim, not: not, resimAdi: resimAdi)
                        } else {
                            vm.kategoriEkle(isim: isim, ustId: ustId, not: not, resimAdi: resimAdi)
                        }
                        kapat()
                    }
                    .disabled(!gecerli)
                }
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Bitti") { kapatKlavye() }
                }
            }
            .onAppear {
                guard !hazirlandi else { return }
                hazirlandi = true
                if let k = duzenle {
                    isim = k.isim
                    not = k.not
                    resimAdi = k.resimAdi
                }
            }
        }
    }
}
