//
//  DepoEkrani.swift
//  Afelay
//
//  Depo sekmesi: istenildiği kadar dallanan kategori gezgini.
//  Her seviyede o dalın toplam adedi / çeşidi görünür.
//

import SwiftUI

struct DepoSekmesi: View {
    let vm: DepoVM
    @State private var yol: [DepoYol] = []

    var body: some View {
        NavigationStack(path: $yol) {
            KategoriEkrani(vm: vm, kategoriId: nil)
                .navigationDestination(for: DepoYol.self) { hedef in
                    switch hedef {
                    case .kategori(let id): KategoriEkrani(vm: vm, kategoriId: id)
                    case .urun(let id):     UrunDetayEkrani(vm: vm, urunId: id)
                    }
                }
        }
    }
}

// MARK: - Bir seviye

struct KategoriEkrani: View {
    let vm: DepoVM
    let kategoriId: UUID?

    @State private var arama = ""
    @State private var aramaGecikmeli = ""
    @State private var yeniKategoriGoster = false
    @State private var konumAkisiGoster = false
    @State private var bekleyenKonum: KonumSecimi?
    @State private var urunFormu: KonumSecimi?
    @State private var buKategoriyiDuzenle = false
    @State private var duzenlenecek: Kategori?
    @State private var silinecek: Kategori?
    @State private var silmeOnayi = false
    @State private var islemHedef: IslemHedef?

    private var kategori: Kategori? { vm.kategori(kategoriId) }
    private var baslik: String { kategori?.isim ?? "Depo" }

    var body: some View {
        List {
            if aramaGecikmeli.trimmingCharacters(in: .whitespaces).isEmpty {
                icerik
            } else {
                aramaIcerigi
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle(baslik)
        .navigationBarTitleDisplayMode(kategoriId == nil ? .large : .inline)
        .searchable(text: $arama, prompt: kategoriId == nil ? "Tüm depoda ara" : "\(baslik) içinde ara")
        .task(id: arama) {
            if arama.isEmpty { aramaGecikmeli = ""; return }
            try? await Task.sleep(for: .milliseconds(180))
            guard !Task.isCancelled else { return }
            aramaGecikmeli = arama
        }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button { yeniKategoriGoster = true } label: {
                        Label("Alt Kategori Ekle", systemImage: "folder.badge.plus")
                    }
                    Button { konumAkisiGoster = true } label: {
                        Label("Ürün Ekle", systemImage: "plus.circle")
                    }
                    if kategoriId != nil {
                        Divider()
                        Button { buKategoriyiDuzenle = true } label: {
                            Label("Bu Kategoriyi Düzenle", systemImage: "pencil")
                        }
                    }
                } label: {
                    Image(systemName: "plus")
                }
            }
        }
        .sheet(isPresented: $yeniKategoriGoster) {
            KategoriSheet(vm: vm, ustId: kategoriId)
        }
        .sheet(isPresented: $konumAkisiGoster, onDismiss: {
            // Konum seçildiyse sheet kapandıktan sonra ürün formunu aç.
            if let b = bekleyenKonum {
                bekleyenKonum = nil
                urunFormu = b
            }
        }) {
            KonumAkisi(vm: vm, baslangic: kategoriId,
                       baslik: "Yeni Ürün",
                       aciklama: "Bu ürün nereye eklensin?") { secilen in
                bekleyenKonum = KonumSecimi(kategoriId: secilen)
            }
        }
        .sheet(item: $urunFormu) { s in
            UrunSheet(vm: vm, kategoriId: s.kategoriId)
        }
        .sheet(isPresented: $buKategoriyiDuzenle) {
            if let k = kategori { KategoriSheet(vm: vm, ustId: k.ustId, duzenle: k) }
        }
        .sheet(item: $duzenlenecek) { k in
            KategoriSheet(vm: vm, ustId: k.ustId, duzenle: k)
        }
        .sheet(item: $islemHedef) { h in
            IslemSheet(vm: vm, urun: h.urun, tip: h.tip)
        }
        .alert("Kategori silinsin mi?", isPresented: $silmeOnayi, presenting: silinecek) { k in
            Button("Sil", role: .destructive) { vm.kategoriSil(k.id) }
            Button("Vazgeç", role: .cancel) {}
        } message: { k in
            Text("\"\(k.isim)\" ile birlikte içindeki tüm alt kategoriler ve ürünler silinecek.")
        }
    }

    // MARK: Normal içerik

    @ViewBuilder private var icerik: some View {
        Section {
            OzetKart(ozet: vm.ozet(kategoriId),
                     yol: kategoriId == nil ? nil : vm.yol(kategoriId))
        }

        if let k = kategori, k.resimAdi != nil || !k.not.isEmpty {
            Section {
                if k.resimAdi != nil {
                    BuyukResim(ad: k.resimAdi, yukseklik: 150, simge: "folder.fill")
                        .listRowInsets(EdgeInsets(top: 6, leading: 12, bottom: 6, trailing: 12))
                }
                if !k.not.isEmpty {
                    VStack(alignment: .leading, spacing: 3) {
                        Text("Not").font(.caption).foregroundStyle(.secondary)
                        Text(k.not)
                    }
                }
            }
        }

        let altlar = vm.altKategoriler(kategoriId)
        if !altlar.isEmpty {
            Section("Kategoriler (\(altlar.count))") {
                ForEach(altlar) { kat in
                    NavigationLink(value: DepoYol.kategori(kat.id)) {
                        KategoriSatiri(vm: vm, kategori: kat)
                    }
                    .swipeActions(edge: .leading) {
                        Button { duzenlenecek = kat } label: {
                            Label("Düzenle", systemImage: "pencil")
                        }
                        .tint(.blue)
                    }
                    .swipeActions(edge: .trailing) {
                        Button(role: .destructive) {
                            silinecek = kat
                            silmeOnayi = true
                        } label: {
                            Label("Sil", systemImage: "trash")
                        }
                    }
                }
            }
        }

        let urunler = vm.dogrudanUrunler(kategoriId)
        if !urunler.isEmpty {
            Section("Ürünler (\(urunler.count))") {
                ForEach(urunler) { u in
                    NavigationLink(value: DepoYol.urun(u.id)) {
                        UrunSatiri(urun: u,
                                   al: { islemHedef = IslemHedef(urun: u, tip: .alis) },
                                   sat: { islemHedef = IslemHedef(urun: u, tip: .satis) })
                    }
                }
                .onDelete { idx in
                    for i in idx { vm.urunSil(urunler[i].id) }
                }
            }
        }

        if altlar.isEmpty && urunler.isEmpty {
            Section {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Burası boş.").font(.headline)
                    Text("Sağ üstteki + ile alt kategori (marka, model...) ya da doğrudan ürün ekleyebilirsin.")
                        .font(.caption).foregroundStyle(.secondary)
                }
                .padding(.vertical, 4)
            }
        }
    }

    // MARK: Arama içeriği

    @ViewBuilder private var aramaIcerigi: some View {
        let sonuc = vm.ara(aramaGecikmeli, kok: kategoriId)

        if sonuc.kategoriler.isEmpty && sonuc.urunler.isEmpty {
            Section { Text("Eşleşen bir şey yok.").foregroundStyle(.secondary) }
        }

        if !sonuc.kategoriler.isEmpty {
            Section("Kategoriler (\(sonuc.kategoriler.count))") {
                ForEach(sonuc.kategoriler) { kat in
                    NavigationLink(value: DepoYol.kategori(kat.id)) {
                        VStack(alignment: .leading, spacing: 3) {
                            KategoriSatiri(vm: vm, kategori: kat)
                            Text(vm.yol(kat.id)).font(.caption2).foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }

        if !sonuc.urunler.isEmpty {
            Section("Ürünler (\(sonuc.urunler.count))") {
                ForEach(sonuc.urunler) { u in
                    NavigationLink(value: DepoYol.urun(u.id)) {
                        VStack(alignment: .leading, spacing: 4) {
                            UrunSatiri(urun: u,
                                       al: { islemHedef = IslemHedef(urun: u, tip: .alis) },
                                       sat: { islemHedef = IslemHedef(urun: u, tip: .satis) })
                            Text(vm.yol(u.kategoriId)).font(.caption2).foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
    }
}

// MARK: - Özet kartı

struct OzetKart: View {
    let ozet: Ozet
    var yol: String?

    var body: some View {
        VStack(spacing: 12) {
            if let yol {
                Text(yol)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            HStack(spacing: 0) {
                buyuk("\(ozet.adet)", "toplam adet", .accentColor)
                Divider().frame(height: 36)
                buyuk("\(ozet.urunSayisi)", "çeşit ürün", .primary)
            }
            HStack(spacing: 8) {
                kucuk("Maliyet", para(ozet.maliyet), .orange)
                kucuk("Satış", para(ozet.satisDegeri), .blue)
                kucuk("Kar", para(ozet.kar), .green)
            }
        }
        .padding(.vertical, 6)
    }

    private func buyuk(_ deger: String, _ baslik: String, _ renk: Color) -> some View {
        VStack(spacing: 2) {
            Text(deger).font(.title2).bold().foregroundStyle(renk)
                .minimumScaleFactor(0.5).lineLimit(1)
            Text(baslik).font(.caption2).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    private func kucuk(_ baslik: String, _ deger: String, _ renk: Color) -> some View {
        VStack(spacing: 2) {
            Text(baslik).font(.caption2).foregroundStyle(.secondary)
            Text(deger).font(.caption).bold().foregroundStyle(renk)
                .minimumScaleFactor(0.5).lineLimit(1)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 6)
        .background(Color(.systemGray6), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}

// MARK: - Kategori satırı

struct KategoriSatiri: View {
    let vm: DepoVM
    let kategori: Kategori

    var body: some View {
        let o = vm.ozet(kategori.id)
        let altSayi = vm.altKategoriler(kategori.id).count

        HStack(spacing: 12) {
            KucukResim(ad: kategori.resimAdi, boyut: 46, simge: "folder.fill", simgeRengi: .accentColor)
            VStack(alignment: .leading, spacing: 3) {
                Text(kategori.isim).font(.headline)
                Text(altSayi > 0
                     ? "\(altSayi) alt başlık • \(o.urunSayisi) çeşit"
                     : "\(o.urunSayisi) çeşit ürün")
                    .font(.caption2).foregroundStyle(.secondary)
            }
            Spacer(minLength: 8)
            VStack(alignment: .trailing, spacing: 0) {
                Text("\(o.adet)").font(.title3).bold().foregroundStyle(.tint)
                Text("adet").font(.caption2).foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 3)
    }
}

// MARK: - Ürün satırı

struct UrunSatiri: View {
    let urun: Urun
    var al: () -> Void
    var sat: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 12) {
                KucukResim(ad: urun.resimAdi, boyut: 50)
                VStack(alignment: .leading, spacing: 2) {
                    Text(urun.isim).font(.headline)
                    Text("Stok: \(urun.miktar)")
                        .font(.caption).bold()
                        .foregroundStyle(urun.miktar == 0 ? .red : (urun.miktar <= 5 ? .orange : .secondary))
                }
                Spacer(minLength: 4)
                VStack(spacing: 6) {
                    Button(action: al) { etiket("Al", .green) }
                        .buttonStyle(.borderless)
                    Button(action: sat) { etiket("Sat", .blue) }
                        .buttonStyle(.borderless)
                        .disabled(urun.miktar == 0)
                }
            }
            HStack(spacing: 6) {
                fiyat("Alış", para(urun.alisFiyati), .secondary)
                fiyat("Satış", para(urun.satisFiyati), .primary)
                fiyat("Kar/adet", para(urun.birimKar), urun.birimKar >= 0 ? .green : .red)
            }
        }
        .padding(.vertical, 4)
    }

    private func etiket(_ t: String, _ c: Color) -> some View {
        Text(t).font(.caption).bold()
            .padding(.horizontal, 12).padding(.vertical, 5)
            .background(c.opacity(0.18), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            .foregroundStyle(c)
    }

    private func fiyat(_ baslik: String, _ deger: String, _ renk: Color) -> some View {
        VStack(spacing: 2) {
            Text(baslik).font(.caption2).foregroundStyle(.secondary)
            Text(deger).font(.caption).bold().foregroundStyle(renk)
                .minimumScaleFactor(0.5).lineLimit(1)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 4)
        .background(Color(.systemGray6), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}
