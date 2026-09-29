//
//  IslemEkranlari.swift
//  Afelay
//
//  Al / Sat sekmeleri, hızlı işlem sayfası ve ürün seçici.
//

import SwiftUI

// MARK: - Ürün seçici (aramalı)

struct UrunSecSheet: View {
    let vm: DepoVM
    @Binding var secili: Urun?
    @Environment(\.dismiss) private var kapat
    @State private var ara = ""

    private var liste: [Urun] {
        let hepsi = vm.urunler.sorted { $0.isim.localizedStandardCompare($1.isim) == .orderedAscending }
        let q = ara.trimmingCharacters(in: .whitespaces)
        guard !q.isEmpty else { return hepsi }
        return hepsi.filter { $0.isim.localizedCaseInsensitiveContains(q) }
    }

    var body: some View {
        NavigationStack {
            List {
                if liste.isEmpty {
                    Text(vm.urunler.isEmpty ? "Henüz ürün yok." : "Eşleşen ürün yok.")
                        .foregroundStyle(.secondary)
                }
                ForEach(liste) { u in
                    Button {
                        secili = u
                        kapat()
                    } label: {
                        HStack(spacing: 12) {
                            KucukResim(ad: u.resimAdi, boyut: 42)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(u.isim).foregroundStyle(.primary)
                                Text(vm.yol(u.kategoriId)).font(.caption2).foregroundStyle(.secondary)
                            }
                            Spacer()
                            Text("\(u.miktar)").font(.subheadline).bold()
                                .foregroundStyle(u.miktar == 0 ? .red : .secondary)
                        }
                    }
                }
            }
            .searchable(text: $ara, prompt: "Ürün ara...")
            .navigationTitle("Ürün Seç")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("İptal") { kapat() } }
            }
        }
    }
}

// MARK: - Tek ürün için hızlı al/sat sayfası

struct IslemSheet: View {
    let vm: DepoVM
    let urun: Urun
    let tip: IslemTipi

    @Environment(\.dismiss) private var kapat
    @State private var adet = ""
    @State private var fiyat = ""
    @State private var kisi = ""
    @State private var hazirlandi = false

    private var guncel: Urun { vm.guncelUrun(urun.id) ?? urun }
    private var dAdet: Int { tamSayiCevir(adet) }
    private var dFiyat: Double { sayiCevir(fiyat) }
    private var stokYeter: Bool { tip == .alis || guncel.miktar >= dAdet }
    private var gecerli: Bool { dAdet > 0 && !fiyat.isEmpty && stokYeter }

    var body: some View {
        NavigationStack {
            Form {
                Section("İşlem") {
                    HStack { Text("Ürün"); Spacer(); Text(urun.isim).bold() }
                    HStack { Text("Mevcut stok"); Spacer(); Text("\(guncel.miktar)").bold() }
                    TextField(tip == .alis ? "Kimden alındı?" : "Kime satıldı?", text: $kisi)
                    HStack {
                        Text("Adet"); Spacer()
                        TextField("0", text: $adet).keyboardType(.numberPad)
                            .multilineTextAlignment(.trailing).frame(maxWidth: 120)
                    }
                    HStack {
                        Text("Birim fiyat ₺"); Spacer()
                        TextField("0", text: $fiyat).keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing).frame(maxWidth: 120)
                    }
                    if dAdet > 0 {
                        HStack {
                            Text("Toplam"); Spacer()
                            Text(para(dFiyat * Double(dAdet))).bold()
                        }
                        if tip == .satis {
                            HStack {
                                Text("Bu satışın karı"); Spacer()
                                Text(para((dFiyat - guncel.alisFiyati) * Double(dAdet)))
                                    .bold().foregroundStyle(.green)
                            }
                        }
                    }
                    if !stokYeter {
                        Text("Stok yetersiz!").font(.caption).bold().foregroundStyle(.red)
                    }
                }

                Button {
                    vm.islemYap(urunId: urun.id, tip: tip, adet: dAdet, fiyat: dFiyat, kisi: kisi)
                    kapat()
                } label: {
                    Text(tip == .alis ? "Depoya Ekle" : "Satışı Onayla")
                        .frame(maxWidth: .infinity).foregroundStyle(.white).bold()
                }
                .listRowBackground(gecerli ? (tip == .alis ? Color.green : Color.blue) : Color.gray)
                .disabled(!gecerli)
            }
            .navigationTitle("\(tip.rawValue) İşlemi")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("İptal") { kapat() } }
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Bitti") { kapatKlavye() }
                }
            }
            .onAppear {
                guard !hazirlandi else { return }
                hazirlandi = true
                fiyat = kisaSayi(tip == .alis ? guncel.alisFiyati : guncel.satisFiyati)
            }
        }
    }
}

// MARK: - Al sekmesi

struct HizliAlEkrani: View {
    let vm: DepoVM

    @State private var yeniMi = false
    @State private var secili: Urun?
    @State private var secGoster = false
    @State private var yeniAd = ""
    @State private var yeniKategori: UUID?
    @State private var refSatis = ""
    @State private var adet = ""
    @State private var fiyat = ""
    @State private var kisi = ""
    @State private var basari = false

    private var gecerli: Bool {
        guard tamSayiCevir(adet) > 0, !fiyat.isEmpty else { return false }
        return yeniMi ? !yeniAd.trimmingCharacters(in: .whitespaces).isEmpty : secili != nil
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Ne alıyorsun?") {
                    Picker("", selection: $yeniMi) {
                        Text("Mevcut Ürün").tag(false)
                        Text("Yeni Ürün").tag(true)
                    }
                    .pickerStyle(.segmented)

                    if yeniMi {
                        TextField("Ürün adı", text: $yeniAd)
                        KonumSecSatiri(vm: vm, kategoriId: $yeniKategori)
                        HStack {
                            Text("Satış fiyatı ₺"); Spacer()
                            TextField("0", text: $refSatis).keyboardType(.decimalPad)
                                .multilineTextAlignment(.trailing).frame(maxWidth: 120)
                        }
                    } else {
                        Button { secGoster = true } label: {
                            HStack {
                                Text(secili?.isim ?? "Ürün seç")
                                    .foregroundStyle(secili == nil ? Color.accentColor : Color.primary)
                                Spacer()
                                if let s = secili, let g = vm.guncelUrun(s.id) {
                                    Text("Stok: \(g.miktar)").font(.caption).foregroundStyle(.secondary)
                                }
                                Image(systemName: "chevron.right").font(.caption).foregroundStyle(.secondary)
                            }
                        }
                        if let s = secili {
                            Text(vm.yol(vm.guncelUrun(s.id)?.kategoriId))
                                .font(.caption2).foregroundStyle(.secondary)
                        }
                    }
                }

                Section("Alış Bilgisi") {
                    HStack {
                        Text("Adet"); Spacer()
                        TextField("0", text: $adet).keyboardType(.numberPad)
                            .multilineTextAlignment(.trailing).frame(maxWidth: 120)
                    }
                    HStack {
                        Text("Alış birim fiyatı ₺"); Spacer()
                        TextField("0", text: $fiyat).keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing).frame(maxWidth: 120)
                    }
                    TextField("Kimden aldın? (opsiyonel)", text: $kisi)
                    if tamSayiCevir(adet) > 0 {
                        HStack {
                            Text("Toplam"); Spacer()
                            Text(para(sayiCevir(fiyat) * Double(tamSayiCevir(adet)))).bold()
                        }
                    }
                }

                Button { satinAl() } label: {
                    Text("Satın Al").frame(maxWidth: .infinity).foregroundStyle(.white).bold()
                }
                .listRowBackground(gecerli ? Color.green : Color.gray)
                .disabled(!gecerli)
            }
            .navigationTitle("Ürün Al")
            .toolbar {
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Bitti") { kapatKlavye() }
                }
            }
            .onChange(of: secili) { _, yeni in
                if let s = yeni, let g = vm.guncelUrun(s.id), fiyat.isEmpty {
                    fiyat = kisaSayi(g.alisFiyati)
                }
            }
            .sheet(isPresented: $secGoster) { UrunSecSheet(vm: vm, secili: $secili) }
            .alert("Eklendi", isPresented: $basari) {
                Button("Tamam", role: .cancel) {}
            } message: { Text("Alış kaydedildi.") }
        }
    }

    private func satinAl() {
        let a = tamSayiCevir(adet)
        let f = sayiCevir(fiyat)
        if yeniMi {
            vm.urunEkle(isim: yeniAd, aciklama: "", alis: f, satis: sayiCevir(refSatis),
                        miktar: a, kategoriId: yeniKategori, resimAdi: nil, kimden: kisi)
        } else if let s = secili {
            vm.islemYap(urunId: s.id, tip: .alis, adet: a, fiyat: f, kisi: kisi)
        }
        adet = ""; fiyat = ""; kisi = ""; yeniAd = ""; refSatis = ""; secili = nil
        kapatKlavye()
        basari = true
    }
}

// MARK: - Sat sekmesi

struct HizliSatEkrani: View {
    let vm: DepoVM

    @State private var secili: Urun?
    @State private var secGoster = false
    @State private var adet = ""
    @State private var fiyat = ""
    @State private var kisi = ""
    @State private var basari = false

    private var guncel: Urun? { vm.guncelUrun(secili?.id) }
    private var dAdet: Int { tamSayiCevir(adet) }
    private var stokYeter: Bool { (guncel?.miktar ?? 0) >= dAdet }
    private var gecerli: Bool { secili != nil && dAdet > 0 && !fiyat.isEmpty && stokYeter }

    var body: some View {
        NavigationStack {
            Form {
                Section("Ne satıyorsun?") {
                    Button { secGoster = true } label: {
                        HStack {
                            Text(secili?.isim ?? "Ürün seç")
                                .foregroundStyle(secili == nil ? Color.accentColor : Color.primary)
                            Spacer()
                            if let g = guncel {
                                Text("Stok: \(g.miktar)").font(.caption).foregroundStyle(.secondary)
                            }
                            Image(systemName: "chevron.right").font(.caption).foregroundStyle(.secondary)
                        }
                    }
                    if let g = guncel {
                        Text(vm.yol(g.kategoriId)).font(.caption2).foregroundStyle(.secondary)
                    }
                }

                Section("Satış Bilgisi") {
                    HStack {
                        Text("Adet"); Spacer()
                        TextField("0", text: $adet).keyboardType(.numberPad)
                            .multilineTextAlignment(.trailing).frame(maxWidth: 120)
                    }
                    HStack {
                        Text("Satış birim fiyatı ₺"); Spacer()
                        TextField("0", text: $fiyat).keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing).frame(maxWidth: 120)
                    }
                    TextField("Kime sattın? (opsiyonel)", text: $kisi)
                    if let g = guncel, dAdet > 0 {
                        HStack {
                            Text("Toplam"); Spacer()
                            Text(para(sayiCevir(fiyat) * Double(dAdet))).bold()
                        }
                        HStack {
                            Text("Bu satışın karı"); Spacer()
                            Text(para((sayiCevir(fiyat) - g.alisFiyati) * Double(dAdet)))
                                .bold().foregroundStyle(.green)
                        }
                    }
                    if secili != nil && !stokYeter {
                        Text("Stok yetersiz!").font(.caption).bold().foregroundStyle(.red)
                    }
                }

                Button { sat() } label: {
                    Text("Satışı Yap").frame(maxWidth: .infinity).foregroundStyle(.white).bold()
                }
                .listRowBackground(gecerli ? Color.blue : Color.gray)
                .disabled(!gecerli)
            }
            .navigationTitle("Ürün Sat")
            .toolbar {
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Bitti") { kapatKlavye() }
                }
            }
            .onChange(of: secili) { _, yeni in
                if let s = yeni, let g = vm.guncelUrun(s.id), fiyat.isEmpty {
                    fiyat = kisaSayi(g.satisFiyati)
                }
            }
            .sheet(isPresented: $secGoster) { UrunSecSheet(vm: vm, secili: $secili) }
            .alert("Satıldı", isPresented: $basari) {
                Button("Tamam", role: .cancel) {}
            } message: { Text("Satış kaydedildi.") }
        }
    }

    private func sat() {
        guard let g = guncel else { return }
        vm.islemYap(urunId: g.id, tip: .satis, adet: dAdet, fiyat: sayiCevir(fiyat), kisi: kisi)
        adet = ""; fiyat = ""; kisi = ""; secili = nil
        kapatKlavye()
        basari = true
    }
}
