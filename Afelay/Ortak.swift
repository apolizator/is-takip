//
//  Ortak.swift
//  Afelay
//
//  Biçimlendirme yardımcıları ve tekrar kullanılan küçük görünümler.
//

import SwiftUI
import UIKit

// MARK: - Yerel ayar

let trYerel = Locale(identifier: "tr_TR")

// MARK: - Sayı / para

private let paraBicim: NumberFormatter = {
    let f = NumberFormatter()
    f.numberStyle = .decimal
    f.maximumFractionDigits = 2
    f.minimumFractionDigits = 0
    f.groupingSeparator = "."
    f.decimalSeparator = ","
    f.locale = trYerel
    return f
}()

/// 1234.5 -> "1.234,5 ₺"
func para(_ d: Double) -> String {
    guard d.isFinite else { return "0 ₺" }
    let v = min(max(d, -1e12), 1e12)
    return (paraBicim.string(from: NSNumber(value: v)) ?? "0") + " ₺"
}

/// Metin alanlarına basmak için: 12.0 -> "12", 12.5 -> "12,5"
func kisaSayi(_ d: Double) -> String {
    guard d.isFinite, abs(d) < 1e12 else { return "0" }
    if d == d.rounded() { return String(Int(d)) }
    return String(format: "%.2f", d).replacingOccurrences(of: ".", with: ",")
}

/// "1.234,56" veya "1234,56" veya "1234.56" -> 1234.56
func sayiCevir(_ s: String) -> Double {
    var t = s.trimmingCharacters(in: .whitespacesAndNewlines)
    if t.contains(",") && t.contains(".") { t = t.replacingOccurrences(of: ".", with: "") }
    t = t.replacingOccurrences(of: ",", with: ".")
    guard let d = Double(t), d.isFinite else { return 0 }
    return min(max(d, -1e12), 1e12)
}

func tamSayiCevir(_ s: String) -> Int {
    let t = s.trimmingCharacters(in: .whitespacesAndNewlines)
    guard let i = Int(t) else { return 0 }
    return min(max(i, 0), 1_000_000_000)
}

func kapatKlavye() {
    UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
}

// MARK: - Tarih

private let gunBicim: DateFormatter = {
    let f = DateFormatter()
    f.locale = trYerel
    f.dateFormat = "d MMMM yyyy, EEEE"
    return f
}()

private let saatBicim: DateFormatter = {
    let f = DateFormatter()
    f.locale = trYerel
    f.dateFormat = "HH:mm"
    return f
}()

private let kisaBicim: DateFormatter = {
    let f = DateFormatter()
    f.locale = trYerel
    f.dateFormat = "d MMM yyyy HH:mm"
    return f
}()

func saatYazi(_ d: Date) -> String { saatBicim.string(from: d) }
func tarihSaatYazi(_ d: Date) -> String { kisaBicim.string(from: d) }

/// "Bugün", "Dün", "Yarın" ya da tam tarih.
func gunEtiketi(_ d: Date) -> String {
    let tak = Calendar.current
    if tak.isDateInToday(d) { return "Bugün" }
    if tak.isDateInYesterday(d) { return "Dün" }
    if tak.isDateInTomorrow(d) { return "Yarın" }
    return gunBicim.string(from: d)
}

func gunBasi(_ d: Date) -> Date { Calendar.current.startOfDay(for: d) }

// MARK: - Resim görünümleri

/// Liste satırları için küçük, önbellekli görsel.
/// Önbellekte hazırsa ilk çizimde anında görünür (kaydırırken titreme olmasın diye).
struct KucukResim: View {
    let ad: String?
    var boyut: CGFloat = 50
    var simge: String = "shippingbox.fill"
    var simgeRengi: Color = .secondary

    @State private var gorsel: UIImage?

    init(ad: String?, boyut: CGFloat = 50,
         simge: String = "shippingbox.fill", simgeRengi: Color = .secondary) {
        self.ad = ad
        self.boyut = boyut
        self.simge = simge
        self.simgeRengi = simgeRengi
        _gorsel = State(initialValue: ad.flatMap { ResimOnbellek.shared.hazir($0) })
    }

    var body: some View {
        ZStack {
            if let g = gorsel {
                Image(uiImage: g).resizable().scaledToFill()
            } else {
                Color(.systemGray6)
                Image(systemName: simge)
                    .font(.system(size: boyut * 0.42))
                    .foregroundStyle(simgeRengi)
            }
        }
        .frame(width: boyut, height: boyut)
        .clipShape(RoundedRectangle(cornerRadius: boyut * 0.24, style: .continuous))
        .task(id: ad) {
            guard let ad else {
                if gorsel != nil { gorsel = nil }
                return
            }
            if let hazir = ResimOnbellek.shared.hazir(ad) {
                if gorsel !== hazir { gorsel = hazir }
                return
            }
            if let yeni = await ResimOnbellek.shared.kucuk(ad) { gorsel = yeni }
        }
    }
}

/// Detay ekranı / form için büyük görsel.
struct BuyukResim: View {
    let ad: String?
    var yukseklik: CGFloat = 160
    var simge: String = "shippingbox.fill"

    @State private var gorsel: UIImage?

    var body: some View {
        ZStack {
            if let g = gorsel {
                Image(uiImage: g).resizable().scaledToFill()
            } else {
                Color(.systemGray6)
                Image(systemName: simge)
                    .font(.system(size: yukseklik * 0.28))
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: yukseklik)
        .clipped()
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .task(id: ad) {
            guard let ad else {
                if gorsel != nil { gorsel = nil }
                return
            }
            gorsel = await ResimOnbellek.shared.buyuk(ad)
        }
    }
}
