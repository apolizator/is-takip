//
//  DepoVM.swift
//  Afelay
//
//  Tüm veriyi tutan tek merkez. Ağaç toplamları (adet/çeşit/tutar) her satır
//  çiziminde yeniden hesaplanmaz; veri her değiştiğinde bir kez indekslenir.
//

import Foundation
import Observation
import UIKit

@Observable
final class DepoVM {

    // MARK: Veri (yalnızca aşağıdaki metotlarla değişir)
    private(set) var kategoriler: [Kategori] = []
    private(set) var urunler: [Urun] = []
    private(set) var islemler: [Islem] = []
    private(set) var gorevler: [Gorev] = []

    /// Depo ağacı (kategori/ürün) her değiştiğinde artar. Önbellek okuyan
    /// metotlar bunu okuyarak SwiftUI'nin ekranı tazelemesini sağlar.
    /// Görev ve işlem listeleri ayrıca gözlendiği için buraya dahil değil;
    /// böylece görev eklemek depo ekranını boş yere tazelemez.
    private(set) var depoSurum: Int = 0

    // MARK: Önbellekler (gözlenmez)
    @ObservationIgnored private var kategoriMap: [UUID: Kategori] = [:]
    @ObservationIgnored private var urunMap: [UUID: Urun] = [:]
    @ObservationIgnored private var altIndeks: [UUID?: [Kategori]] = [:]
    @ObservationIgnored private var urunIndeks: [UUID?: [Urun]] = [:]
    @ObservationIgnored private var ozetIndeks: [UUID?: Ozet] = [:]
    @ObservationIgnored private var yolIndeks: [UUID: String] = [:]
    @ObservationIgnored private var atalarIndeks: [UUID: Set<UUID>] = [:]
    @ObservationIgnored private var secenekler: [KategoriSecim] = []

    // MARK: - Açılış

    init() {
        _ = Depolama.shared.gocEtVarsa()
        let d = Depolama.shared
        kategoriler = d.oku([Kategori].self, Dosya.kategoriler) ?? []
        urunler = d.oku([Urun].self, Dosya.urunler) ?? []
        islemler = d.oku([Islem].self, Dosya.islemler) ?? []
        gorevler = d.oku([Gorev].self, Dosya.gorevler) ?? []

        if onar() {
            d.yaz(kategoriler, Dosya.kategoriler)
            d.yaz(urunler, Dosya.urunler)
        }
        indeksleriKur()
        ResimDeposu.temizle(kullanilan: kullanilanResimler())
    }

    /// Sahipsiz kayıtları ve (varsa) kategori döngülerini onarır.
    /// Döngü, eski sürümde yol hesabında sonsuz döngüye yol açabiliyordu.
    private func onar() -> Bool {
        var degisti = false
        let idler = Set(kategoriler.map(\.id))

        for i in kategoriler.indices {
            if let u = kategoriler[i].ustId, u == kategoriler[i].id || !idler.contains(u) {
                kategoriler[i].ustId = nil
                degisti = true
            }
        }

        var ustMap: [UUID: UUID?] = [:]
        for k in kategoriler { ustMap[k.id] = k.ustId }
        for k in kategoriler {
            var gorulen: Set<UUID> = [k.id]
            var mevcut = ustMap[k.id] ?? nil
            var adim = 0
            while let c = mevcut, adim < 10_000 {
                if gorulen.contains(c) {
                    if let j = kategoriler.firstIndex(where: { $0.id == c }) {
                        kategoriler[j].ustId = nil
                        ustMap[c] = UUID?.none
                        degisti = true
                    }
                    break
                }
                gorulen.insert(c)
                mevcut = ustMap[c] ?? nil
                adim += 1
            }
        }

        for i in urunler.indices {
            if let k = urunler[i].kategoriId, !idler.contains(k) {
                urunler[i].kategoriId = nil
                degisti = true
            }
        }
        return degisti
    }

    // MARK: - İndeksleme

    private func indeksleriKur() {
        kategoriMap = Dictionary(kategoriler.map { ($0.id, $0) }, uniquingKeysWith: { a, _ in a })
        urunMap = Dictionary(urunler.map { ($0.id, $0) }, uniquingKeysWith: { a, _ in a })

        altIndeks = Dictionary(grouping: kategoriler, by: { $0.ustId })
            .mapValues { $0.sorted { $0.isim.localizedStandardCompare($1.isim) == .orderedAscending } }
        urunIndeks = Dictionary(grouping: urunler, by: { $0.kategoriId })
            .mapValues { $0.sorted { $0.isim.localizedStandardCompare($1.isim) == .orderedAscending } }

        ozetIndeks = [:]
        yolIndeks = [:]
        atalarIndeks = [:]

        var ziyaret = Set<UUID>()
        _ = hesapla(nil, yol: "", atalar: [], ziyaret: &ziyaret)
        // Kök altından ulaşılamayan bir şey kalırsa (olmamalı) onu da hesapla.
        for k in kategoriler where !ziyaret.contains(k.id) {
            ziyaret.insert(k.id)
            yolIndeks[k.id] = k.isim
            atalarIndeks[k.id] = []
            _ = hesapla(k.id, yol: k.isim, atalar: [], ziyaret: &ziyaret)
        }

        secenekler = kategoriler
            .map { KategoriSecim(id: $0.id, yol: yolIndeks[$0.id] ?? $0.isim) }
            .sorted { $0.yol.localizedStandardCompare($1.yol) == .orderedAscending }
    }

    @discardableResult
    private func hesapla(_ id: UUID?, yol: String, atalar: Set<UUID>, ziyaret: inout Set<UUID>) -> Ozet {
        var o = Ozet.bos
        for u in urunIndeks[id] ?? [] { o.ekle(u) }

        var altAtalar = atalar
        if let id { altAtalar.insert(id) }

        for k in altIndeks[id] ?? [] {
            guard !ziyaret.contains(k.id) else { continue }
            ziyaret.insert(k.id)
            let altYol = yol.isEmpty ? k.isim : yol + " / " + k.isim
            yolIndeks[k.id] = altYol
            atalarIndeks[k.id] = altAtalar
            o.topla(hesapla(k.id, yol: altYol, atalar: altAtalar, ziyaret: &ziyaret))
        }
        ozetIndeks[id] = o
        return o
    }

    private func guncellendi(kategori: Bool = false, urun: Bool = false,
                             islem: Bool = false, gorev: Bool = false) {
        if kategori || urun {
            indeksleriKur()
            depoSurum &+= 1
        }
        let d = Depolama.shared
        if kategori { d.yaz(kategoriler, Dosya.kategoriler) }
        if urun { d.yaz(urunler, Dosya.urunler) }
        if islem { d.yaz(islemler, Dosya.islemler) }
        if gorev { d.yaz(gorevler, Dosya.gorevler) }
    }

    private func kullanilanResimler() -> Set<String> {
        var s = Set<String>()
        for u in urunler { if let a = u.resimAdi { s.insert(a) } }
        for k in kategoriler { if let a = k.resimAdi { s.insert(a) } }
        return s
    }

    // MARK: - Sorgular (hepsi önbellekten)

    func altKategoriler(_ id: UUID?) -> [Kategori] {
        _ = depoSurum
        return altIndeks[id] ?? []
    }

    func dogrudanUrunler(_ id: UUID?) -> [Urun] {
        _ = depoSurum
        return urunIndeks[id] ?? []
    }

    func ozet(_ id: UUID?) -> Ozet {
        _ = depoSurum
        return ozetIndeks[id] ?? .bos
    }

    func kategori(_ id: UUID?) -> Kategori? {
        _ = depoSurum
        guard let id else { return nil }
        return kategoriMap[id]
    }

    func guncelUrun(_ id: UUID?) -> Urun? {
        _ = depoSurum
        guard let id else { return nil }
        return urunMap[id]
    }

    func yol(_ id: UUID?) -> String {
        _ = depoSurum
        guard let id, let y = yolIndeks[id] else { return "Ana Depo" }
        return y
    }

    func kategoriSecenekleri() -> [KategoriSecim] {
        _ = depoSurum
        return secenekler
    }

    func urunHareketleri(_ urunId: UUID) -> [Islem] {
        _ = depoSurum
        return islemler.filter { $0.urunId == urunId }
    }

    private func kategoriAgactaMi(_ id: UUID, kok: UUID?) -> Bool {
        guard let kok else { return true }
        if id == kok { return true }
        return atalarIndeks[id]?.contains(kok) ?? false
    }

    /// Bir daldaki (ya da tüm depodaki) arama.
    func ara(_ metin: String, kok: UUID?) -> (kategoriler: [Kategori], urunler: [Urun]) {
        _ = depoSurum
        let q = metin.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !q.isEmpty else { return ([], []) }

        let kats = kategoriler
            .filter { $0.isim.localizedCaseInsensitiveContains(q) && kategoriAgactaMi($0.id, kok: kok) && $0.id != kok }
            .sorted { yol($0.id).localizedStandardCompare(yol($1.id)) == .orderedAscending }

        let urs = urunler
            .filter { u in
                guard u.isim.localizedCaseInsensitiveContains(q) || u.aciklama.localizedCaseInsensitiveContains(q) else { return false }
                guard let kok else { return true }
                guard let kid = u.kategoriId else { return false }
                return kategoriAgactaMi(kid, kok: kok)
            }
            .sorted { $0.isim.localizedStandardCompare($1.isim) == .orderedAscending }

        return (kats, urs)
    }

    // MARK: - Kategori işlemleri

    @discardableResult
    func kategoriEkle(isim: String, ustId: UUID?, not: String = "", resimAdi: String? = nil) -> UUID? {
        let ad = isim.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !ad.isEmpty else { return nil }
        let k = Kategori(isim: ad, ustId: ustId, not: not, resimAdi: resimAdi)
        kategoriler.append(k)
        guncellendi(kategori: true)
        return k.id
    }

    func kategoriGuncelle(id: UUID, isim: String, not: String, resimAdi: String?) {
        let ad = isim.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !ad.isEmpty, let i = kategoriler.firstIndex(where: { $0.id == id }) else { return }
        let eskiResim = kategoriler[i].resimAdi
        kategoriler[i].isim = ad
        kategoriler[i].not = not
        kategoriler[i].resimAdi = resimAdi
        if let eskiResim, eskiResim != resimAdi { ResimDeposu.sil(eskiResim) }
        guncellendi(kategori: true)
    }

    func kategoriSil(_ id: UUID) {
        var silinecekKategoriler: Set<UUID> = []
        topla(id, &silinecekKategoriler)

        for u in urunler where u.kategoriId.map({ silinecekKategoriler.contains($0) }) == true {
            ResimDeposu.sil(u.resimAdi)
        }
        for k in kategoriler where silinecekKategoriler.contains(k.id) {
            ResimDeposu.sil(k.resimAdi)
        }
        urunler.removeAll { u in u.kategoriId.map { silinecekKategoriler.contains($0) } == true }
        kategoriler.removeAll { silinecekKategoriler.contains($0.id) }
        guncellendi(kategori: true, urun: true)
    }

    private func topla(_ id: UUID, _ kume: inout Set<UUID>) {
        guard !kume.contains(id) else { return }
        kume.insert(id)
        for alt in altIndeks[id] ?? [] { topla(alt.id, &kume) }
    }

    // MARK: - Ürün işlemleri

    func urunEkle(isim: String, aciklama: String, alis: Double, satis: Double, miktar: Int,
                  kategoriId: UUID?, resimAdi: String?, kimden: String) {
        let ad = isim.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !ad.isEmpty else { return }
        let u = Urun(isim: ad, aciklama: aciklama, alisFiyati: alis, satisFiyati: satis,
                     miktar: 0, kategoriId: kategoriId, resimAdi: resimAdi)
        urunler.append(u)
        guncellendi(urun: true)
        if miktar > 0 {
            islemYap(urunId: u.id, tip: .alis, adet: miktar, fiyat: alis, kisi: kimden, urunIsmi: ad)
        }
    }

    func urunGuncelle(id: UUID, isim: String, aciklama: String, alis: Double, satis: Double,
                      kategoriId: UUID?, resimAdi: String?) {
        guard let i = urunler.firstIndex(where: { $0.id == id }) else { return }
        let eskiResim = urunler[i].resimAdi
        urunler[i].isim = isim.trimmingCharacters(in: .whitespacesAndNewlines)
        urunler[i].aciklama = aciklama
        urunler[i].alisFiyati = alis
        urunler[i].satisFiyati = satis
        urunler[i].kategoriId = kategoriId
        urunler[i].resimAdi = resimAdi
        if let eskiResim, eskiResim != resimAdi { ResimDeposu.sil(eskiResim) }
        guncellendi(urun: true)
    }

    func urunTasi(id: UUID, kategoriId: UUID?) {
        guard let i = urunler.firstIndex(where: { $0.id == id }) else { return }
        urunler[i].kategoriId = kategoriId
        guncellendi(urun: true)
    }

    func stokDuzelt(id: UUID, yeniMiktar: Int) {
        guard let i = urunler.firstIndex(where: { $0.id == id }) else { return }
        urunler[i].miktar = max(0, yeniMiktar)
        guncellendi(urun: true)
    }

    func urunSil(_ id: UUID) {
        if let u = urunler.first(where: { $0.id == id }) { ResimDeposu.sil(u.resimAdi) }
        urunler.removeAll { $0.id == id }
        guncellendi(urun: true)
    }

    // MARK: - Alış / satış

    func islemYap(urunId: UUID, tip: IslemTipi, adet: Int, fiyat: Double, kisi: String, urunIsmi: String? = nil) {
        guard adet > 0, let i = urunler.firstIndex(where: { $0.id == urunId }) else { return }
        var kar: Double = 0
        if tip == .satis {
            guard urunler[i].miktar >= adet else { return }   // stok kontrolü
            urunler[i].miktar -= adet
            kar = (fiyat - urunler[i].alisFiyati) * Double(adet)
        } else {
            urunler[i].miktar += adet
        }
        let isim = urunIsmi ?? urunler[i].isim
        let yeni = Islem(urunId: urunId, urunIsmi: isim, tip: tip, tarih: Date(),
                         adet: adet, birimFiyat: fiyat,
                         kisi: kisi.trimmingCharacters(in: .whitespaces).isEmpty ? "—" : kisi,
                         kar: kar)
        islemler.insert(yeni, at: 0)
        guncellendi(urun: true, islem: true)
    }

    /// Hareket silinince stok da geri alınır (eskiden stok tutarsız kalıyordu).
    func islemSil(_ id: UUID) {
        guard let idx = islemler.firstIndex(where: { $0.id == id }) else { return }
        let h = islemler[idx]
        if let i = urunler.firstIndex(where: { $0.id == h.urunId }) {
            if h.tip == .alis { urunler[i].miktar = max(0, urunler[i].miktar - h.adet) }
            else { urunler[i].miktar += h.adet }
        }
        islemler.remove(at: idx)
        guncellendi(urun: true, islem: true)
    }

    // MARK: - Görevler / günlük

    func gorevEkle(metin: String, tur: GorevTuru, tarih: Date, tamamlandi: Bool) {
        let m = metin.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !m.isEmpty else { return }
        gorevler.append(Gorev(metin: m, tur: tur, tarih: tarih, tamamlandi: tamamlandi))
        guncellendi(gorev: true)
    }

    func gorevGuncelle(id: UUID, metin: String, tur: GorevTuru, tarih: Date, tamamlandi: Bool) {
        guard let i = gorevler.firstIndex(where: { $0.id == id }) else { return }
        let m = metin.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !m.isEmpty else { return }
        gorevler[i].metin = m
        gorevler[i].tur = tur
        gorevler[i].tarih = tarih
        gorevler[i].tamamlandi = tamamlandi
        guncellendi(gorev: true)
    }

    func gorevDurumDegistir(_ id: UUID) {
        guard let i = gorevler.firstIndex(where: { $0.id == id }) else { return }
        gorevler[i].tamamlandi.toggle()
        guncellendi(gorev: true)
    }

    func gorevSil(_ id: UUID) {
        gorevler.removeAll { $0.id == id }
        guncellendi(gorev: true)
    }

    // MARK: - Yedek / paylaşım

    func paket(resimlerle: Bool) -> AktarimPaketi {
        var p = AktarimPaketi()
        p.cihaz = UIDevice.current.name
        p.kategoriler = kategoriler
        p.urunler = urunler
        p.islemler = islemler
        p.gorevler = gorevler
        if resimlerle {
            for ad in kullanilanResimler() {
                if let veri = ResimDeposu.buyukVeri(ad) { p.resimler[ad] = veri }
            }
        }
        return p
    }

    /// Yedeği uygular. `degistir` true ise mevcut veri silinir, false ise birleştirilir.
    @discardableResult
    func paketiUygula(_ p: AktarimPaketi, degistir: Bool) -> String {
        for (ad, veri) in p.resimler where !veri.isEmpty {
            let varMi = FileManager.default.fileExists(atPath: ResimDeposu.buyukUrl(ad).path)
            if degistir || !varMi { _ = ResimDeposu.hamKaydet(veri, ad: ad) }
        }

        let oncekiUrun = urunler.count
        let oncekiKategori = kategoriler.count
        let oncekiGorev = gorevler.count

        if degistir {
            kategoriler = p.kategoriler
            urunler = p.urunler
            islemler = p.islemler
            gorevler = p.gorevler
        } else {
            birlestir(p)
        }

        _ = onar()
        indeksleriKur()
        depoSurum &+= 1

        let d = Depolama.shared
        d.yaz(kategoriler, Dosya.kategoriler)
        d.yaz(urunler, Dosya.urunler)
        d.yaz(islemler, Dosya.islemler)
        d.yaz(gorevler, Dosya.gorevler)
        d.hemenKaydet()
        ResimOnbellek.shared.temizle()
        ResimDeposu.temizle(kullanilan: kullanilanResimler())

        if degistir {
            return "Yedek yüklendi. \(kategoriler.count) kategori, \(urunler.count) ürün, \(gorevler.count) görev."
        }
        let yeniK = kategoriler.count - oncekiKategori
        let yeniU = urunler.count - oncekiUrun
        let yeniG = gorevler.count - oncekiGorev
        return "Birleştirildi. Yeni: \(yeniK) kategori, \(yeniU) ürün, \(yeniG) görev."
    }

    /// Aynı isim + aynı üst başlık olan kategorileri tek başlıkta toplar,
    /// gelen ürünleri o başlıklara bağlar. Var olan kayıtlara dokunmaz.
    private func birlestir(_ p: AktarimPaketi) {
        var eslesme: [UUID: UUID] = [:]
        var anahtarlar: [String: UUID] = [:]

        func anahtar(_ ust: UUID?, _ isim: String) -> String {
            (ust?.uuidString ?? "KOK") + "|" + isim.lowercased()
        }
        for k in kategoriler { anahtarlar[anahtar(k.ustId, k.isim)] = k.id }
        let mevcutKategoriIdler = Set(kategoriler.map(\.id))

        let gelenAlt = Dictionary(grouping: p.kategoriler, by: { $0.ustId })
        var islenen = Set<UUID>()

        func isle(_ gelenUst: UUID?, _ yerelUst: UUID?) {
            for gelen in gelenAlt[gelenUst] ?? [] {
                guard !islenen.contains(gelen.id) else { continue }
                islenen.insert(gelen.id)
                let a = anahtar(yerelUst, gelen.isim)
                if let varOlan = anahtarlar[a] {
                    eslesme[gelen.id] = varOlan
                    isle(gelen.id, varOlan)
                } else {
                    var yeni = gelen
                    yeni.ustId = yerelUst
                    if mevcutKategoriIdler.contains(gelen.id) { yeni.id = UUID() }
                    kategoriler.append(yeni)
                    anahtarlar[a] = yeni.id
                    eslesme[gelen.id] = yeni.id
                    isle(gelen.id, yeni.id)
                }
            }
        }
        isle(nil, nil)

        let mevcutUrunIdler = Set(urunler.map(\.id))
        for u in p.urunler where !mevcutUrunIdler.contains(u.id) {
            var yeni = u
            yeni.kategoriId = u.kategoriId.flatMap { eslesme[$0] }
            urunler.append(yeni)
        }

        let mevcutIslemIdler = Set(islemler.map(\.id))
        islemler.append(contentsOf: p.islemler.filter { !mevcutIslemIdler.contains($0.id) })
        islemler.sort { $0.tarih > $1.tarih }

        let mevcutGorevIdler = Set(gorevler.map(\.id))
        gorevler.append(contentsOf: p.gorevler.filter { !mevcutGorevIdler.contains($0.id) })
    }

    // MARK: - Sıfırlama

    func sistemiSifirla() {
        kategoriler.removeAll()
        urunler.removeAll()
        islemler.removeAll()
        gorevler.removeAll()
        ResimDeposu.tumunuSil()
        ResimOnbellek.shared.temizle()
        guncellendi(kategori: true, urun: true, islem: true, gorev: true)
        Depolama.shared.hemenKaydet()
    }
}
