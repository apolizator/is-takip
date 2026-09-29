//
//  BilancoEkrani.swift
//  Afelay
//

import SwiftUI

struct BilancoEkrani: View {
    let vm: DepoVM

    @State private var u1 = false
    @State private var u2 = false
    @State private var u3 = false

    var body: some View {
        NavigationStack {
            List {
                let o = vm.ozet(nil)
                let bugun = gunBasi(Date())
                let bugunkuler = vm.islemler.filter { gunBasi($0.tarih) == bugun }
                let satislar = bugunkuler.filter { $0.tip == .satis }
                let alislar = bugunkuler.filter { $0.tip == .alis }

                Section("Bugün") {
                    bilgi("Net kar", para(satislar.reduce(0) { $0 + $1.kar }), .green)
                    bilgi("Ciro", para(satislar.reduce(0) { $0 + $1.tutar }), .blue)
                    bilgi("Satılan adet", "\(satislar.reduce(0) { $0 + $1.adet })", .primary)
                    bilgi("Alıma harcanan", para(alislar.reduce(0) { $0 + $1.tutar }), .orange)
                    bilgi("Alınan adet", "\(alislar.reduce(0) { $0 + $1.adet })", .primary)
                }

                Section("Genel Stok Durumu") {
                    bilgi("Toplam potansiyel kar", para(o.kar), .green)
                    bilgi("Toplam satış değeri", para(o.satisDegeri), .blue)
                    bilgi("Toplam stok maliyeti", para(o.maliyet), .orange)
                    bilgi("Çeşit ürün", "\(o.urunSayisi)", .primary)
                    bilgi("Toplam adet", "\(o.adet)", .primary)
                    bilgi("Kategori sayısı", "\(vm.kategoriler.count)", .primary)
                }

                Section("Görev Defteri") {
                    let bekleyen = vm.gorevler.filter { !$0.tamamlandi }.count
                    bilgi("Bekleyen", "\(bekleyen)", bekleyen > 0 ? .orange : .secondary)
                    bilgi("Tamamlanan", "\(vm.gorevler.count - bekleyen)", .green)
                }

                Section("Son Hareketler") {
                    let son = Array(vm.islemler.prefix(10))
                    if son.isEmpty {
                        Text("Henüz hareket yok.").foregroundStyle(.secondary)
                    }
                    ForEach(son) { h in
                        HStack(alignment: .top) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(h.urunIsmi).font(.subheadline).bold()
                                Text("\(h.tip.rawValue) • \(h.adet) adet • \(h.kisi)")
                                    .font(.caption2).foregroundStyle(.secondary)
                                Text(tarihSaatYazi(h.tarih)).font(.caption2).foregroundStyle(.secondary)
                            }
                            Spacer()
                            Text(para(h.tutar)).font(.caption).bold()
                                .foregroundStyle(h.tip == .alis ? .orange : .blue)
                        }
                        .padding(.vertical, 2)
                    }
                }

                AktarimBolumu(vm: vm)

                Section("Tehlikeli Bölge") {
                    Button {
                        u1 = true
                    } label: {
                        Label("Sistemi Tamamen Sıfırla", systemImage: "trash.circle.fill")
                            .foregroundStyle(.red).bold()
                    }
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Bilanço")
            .alert("TÜM VERİLER SİLİNSİN Mİ?", isPresented: $u1) {
                Button("Evet, Sıfırla", role: .destructive) { u2 = true }
                Button("Vazgeç", role: .cancel) {}
            } message: {
                Text("Ürünler, kategoriler, görevler ve tüm geçmiş silinecek. Emin misin?")
            }
            .alert("BAK CİDDİYİM!", isPresented: $u2) {
                Button("Geri Dönüş Yok, Sil!", role: .destructive) { u3 = true }
                Button("Dur, vazgeçtim", role: .cancel) {}
            } message: {
                Text("Bu işlem geri alınamaz. Uygulama ilk indirildiğindeki gibi bomboş olacak.")
            }
            .alert("SON KARARIN MI?", isPresented: $u3) {
                Button("SON KEZ DİYORUM: SİL!", role: .destructive) { vm.sistemiSifirla() }
                Button("Kapat, silme!", role: .cancel) {}
            } message: {
                Text("Eğer onaylarsan her şey sonsuza dek gider.")
            }
        }
    }

    private func bilgi(_ l: String, _ v: String, _ c: Color) -> some View {
        HStack {
            Text(l)
            Spacer()
            Text(v).bold().foregroundStyle(c)
        }
    }
}
