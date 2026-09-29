//
//  Aktarim.swift
//  Afelay
//
//  Yedek alma / paylaşma ve yedekten yükleme.
//  Tüm veri tek bir .json dosyasına konur; istenirse fotoğraflar da
//  dosyanın içine gömülür, böylece tek dosya WhatsApp/AirDrop ile gider.
//

import SwiftUI
import UIKit
import UniformTypeIdentifiers

// MARK: - Paket

nonisolated struct AktarimPaketi: Codable {
    var surum: Int = 1
    var olusturma: Date = Date()
    var cihaz: String = ""
    var kategoriler: [Kategori] = []
    var urunler: [Urun] = []
    var islemler: [Islem] = []
    var gorevler: [Gorev] = []
    var resimler: [String: Data] = [:]      // dosya adı -> jpeg (JSON'da base64)

    var ozetYazi: String {
        "\(kategoriler.count) kategori • \(urunler.count) ürün • \(gorevler.count) görev"
    }

    init() {}

    enum CodingKeys: String, CodingKey {
        case surum, olusturma, cihaz, kategoriler, urunler, islemler, gorevler, resimler
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        surum = try c.decodeIfPresent(Int.self, forKey: .surum) ?? 1
        olusturma = try c.decodeIfPresent(Date.self, forKey: .olusturma) ?? Date()
        cihaz = try c.decodeIfPresent(String.self, forKey: .cihaz) ?? ""
        kategoriler = try c.decodeIfPresent([Kategori].self, forKey: .kategoriler) ?? []
        urunler = try c.decodeIfPresent([Urun].self, forKey: .urunler) ?? []
        islemler = try c.decodeIfPresent([Islem].self, forKey: .islemler) ?? []
        gorevler = try c.decodeIfPresent([Gorev].self, forKey: .gorevler) ?? []
        resimler = try c.decodeIfPresent([String: Data].self, forKey: .resimler) ?? [:]
    }
}

// Dışa ve içe aktarma aynı ayarları kullanmalı; ikisi de burada.
nonisolated enum AktarimBicimi {
    // Tarih stratejisi bilerek varsayılan bırakıldı: iso8601 salise kaybettiriyor,
    // varsayılan (Double) ise tarihi birebir koruyor. İkisi de burada tanımlı ki
    // yazma ve okuma asla ayrışmasın.
    static func kodlayici() -> JSONEncoder { JSONEncoder() }
    static func cozucu() -> JSONDecoder { JSONDecoder() }

    static func dosyaYaz(_ paket: AktarimPaketi) -> URL? {
        guard let veri = try? kodlayici().encode(paket) else { return nil }
        let f = DateFormatter()
        f.locale = Locale(identifier: "tr_TR")
        f.dateFormat = "dd-MM-yyyy-HHmm"
        let ad = "Afelay-Yedek-\(f.string(from: Date())).json"
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(ad)
        do { try veri.write(to: url, options: .atomic) } catch { return nil }
        return url
    }

    static func dosyaOku(_ url: URL) -> AktarimPaketi? {
        let erisim = url.startAccessingSecurityScopedResource()
        defer { if erisim { url.stopAccessingSecurityScopedResource() } }
        guard let veri = try? Data(contentsOf: url) else { return nil }
        return try? cozucu().decode(AktarimPaketi.self, from: veri)
    }
}

// MARK: - Paylaşım sayfası

nonisolated struct PaylasilacakDosya: Identifiable {
    let id = UUID()
    let url: URL
}

struct PaylasimSayfasi: UIViewControllerRepresentable {
    let url: URL

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: [url], applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

// MARK: - Bilanço içindeki bölüm

struct AktarimBolumu: View {
    let vm: DepoVM

    @State private var hazirlaniyor = false
    @State private var paylasilacak: PaylasilacakDosya?
    @State private var dosyaSecGoster = false
    @State private var gelenPaket: AktarimPaketi?
    @State private var modSor = false
    @State private var mesaj: String?
    @State private var mesajGoster = false

    var body: some View {
        Section {
            Button { disaAktar(resimlerle: true) } label: {
                Label("Yedeği paylaş (fotoğraflarla)", systemImage: "square.and.arrow.up")
            }
            .disabled(hazirlaniyor)

            Button { disaAktar(resimlerle: false) } label: {
                Label("Yedeği paylaş (sadece veri, küçük dosya)", systemImage: "square.and.arrow.up.on.square")
            }
            .disabled(hazirlaniyor)

            Button { dosyaSecGoster = true } label: {
                Label("Yedekten yükle", systemImage: "square.and.arrow.down")
            }
            .disabled(hazirlaniyor)

            if hazirlaniyor {
                HStack(spacing: 8) {
                    ProgressView()
                    Text("Hazırlanıyor...").font(.caption).foregroundStyle(.secondary)
                }
            }
        } header: {
            Text("Yedek ve Paylaşım")
        } footer: {
            Text("Yedeği WhatsApp/AirDrop ile başka bir telefona gönder, orada \"Yedekten yükle\" ile aç. Birleştirirsen aynı isimli kategoriler tek başlıkta toplanır, mevcut kayıtların bozulmaz.")
        }
        .sheet(item: $paylasilacak) { d in
            PaylasimSayfasi(url: d.url)
        }
        .fileImporter(isPresented: $dosyaSecGoster, allowedContentTypes: [.json, .data]) { sonuc in
            switch sonuc {
            case .success(let url):
                if let p = AktarimBicimi.dosyaOku(url) {
                    gelenPaket = p
                    modSor = true
                } else {
                    mesaj = "Dosya okunamadı. Afelay yedek dosyası olduğundan emin ol."
                    mesajGoster = true
                }
            case .failure(let h):
                mesaj = h.localizedDescription
                mesajGoster = true
            }
        }
        .confirmationDialog("Yedek bulundu", isPresented: $modSor, presenting: gelenPaket) { p in
            Button("Birleştir (önerilen)") { uygula(p, degistir: false) }
            Button("Hepsini değiştir", role: .destructive) { uygula(p, degistir: true) }
            Button("Vazgeç", role: .cancel) { gelenPaket = nil }
        } message: { p in
            Text("\(p.ozetYazi)\n\nBirleştir: eksik kayıtlar eklenir, mevcutlar kalır.\nHepsini değiştir: şu anki verinin üstüne yazılır.")
        }
        .alert("Bilgi", isPresented: $mesajGoster) {
            Button("Tamam", role: .cancel) {}
        } message: {
            Text(mesaj ?? "")
        }
    }

    private func disaAktar(resimlerle: Bool) {
        hazirlaniyor = true
        let paket = vm.paket(resimlerle: resimlerle)
        Task {
            let url = await Task.detached(priority: .userInitiated) {
                AktarimBicimi.dosyaYaz(paket)
            }.value
            hazirlaniyor = false
            if let url {
                paylasilacak = PaylasilacakDosya(url: url)
            } else {
                mesaj = "Yedek dosyası oluşturulamadı."
                mesajGoster = true
            }
        }
    }

    private func uygula(_ p: AktarimPaketi, degistir: Bool) {
        hazirlaniyor = true
        let sonuc = vm.paketiUygula(p, degistir: degistir)
        hazirlaniyor = false
        gelenPaket = nil
        mesaj = sonuc
        mesajGoster = true
    }
}
