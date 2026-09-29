//
//  GorevEkrani.swift
//  Afelay
//
//  Günlük / görev defteri: tarih ve saatiyle birlikte "alındı, alınacak,
//  gidilecek, gidildi, yapıldı" tarzı serbest notlar.
//

import SwiftUI

enum GorevSuzgec: String, CaseIterable, Identifiable {
    case hepsi = "Hepsi"
    case bekleyen = "Bekleyen"
    case biten = "Biten"
    var id: String { rawValue }
}

func turRengi(_ t: GorevTuru) -> Color {
    switch t {
    case .not:   return .gray
    case .alim:  return .green
    case .satim: return .blue
    case .yer:   return .orange
    case .is_:   return .purple
    }
}

struct GorevEkrani: View {
    let vm: DepoVM

    @State private var suzgec: GorevSuzgec = .hepsi
    @State private var arama = ""
    @State private var aramaGecikmeli = ""
    @State private var yeniGoster = false
    @State private var duzenlenecek: Gorev?

    // Gün gün gruplanmış liste: günler yeniden eskiye, gün içi saate göre.
    private var gruplar: [(gun: Date, kayitlar: [Gorev])] {
        let q = aramaGecikmeli.trimmingCharacters(in: .whitespacesAndNewlines)
        let suzulmus = vm.gorevler.filter { g in
            switch suzgec {
            case .hepsi:    break
            case .bekleyen: if g.tamamlandi { return false }
            case .biten:    if !g.tamamlandi { return false }
            }
            if q.isEmpty { return true }
            return g.metin.localizedCaseInsensitiveContains(q) || g.tur.baslik.localizedCaseInsensitiveContains(q)
        }
        let sozluk = Dictionary(grouping: suzulmus) { gunBasi($0.tarih) }
        return sozluk.keys.sorted(by: >).map { gun in
            (gun, (sozluk[gun] ?? []).sorted { $0.tarih < $1.tarih })
        }
    }

    private var bekleyenSayi: Int { vm.gorevler.filter { !$0.tamamlandi }.count }
    private var bugunSayi: Int {
        let b = gunBasi(Date())
        return vm.gorevler.filter { gunBasi($0.tarih) == b }.count
    }

    var body: some View {
        NavigationStack {
            Group {
                if vm.gorevler.isEmpty {
                    ContentUnavailableView {
                        Label("Defter boş", systemImage: "checklist")
                    } description: {
                        Text("Sağ üstteki + ile ilk kaydını ekle.\nÖrn: \"Yarın Ahmet'ten 10 kutu alınacak\".")
                    }
                } else {
                    liste
                }
            }
            .navigationTitle("Görev Defteri")
            .searchable(text: $arama, prompt: "Görevlerde ara...")
            .task(id: arama) {
                if arama.isEmpty { aramaGecikmeli = ""; return }
                try? await Task.sleep(for: .milliseconds(180))
                guard !Task.isCancelled else { return }
                aramaGecikmeli = arama
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { yeniGoster = true } label: { Image(systemName: "plus") }
                }
            }
            .sheet(isPresented: $yeniGoster) { GorevSheet(vm: vm) }
            .sheet(item: $duzenlenecek) { g in GorevSheet(vm: vm, duzenle: g) }
        }
    }

    private var liste: some View {
        List {
            Section {
                HStack(spacing: 0) {
                    sayac("\(bekleyenSayi)", "bekleyen", .orange)
                    Divider().frame(height: 30)
                    sayac("\(bugunSayi)", "bugün", .accentColor)
                    Divider().frame(height: 30)
                    sayac("\(vm.gorevler.count)", "toplam", .primary)
                }
                Picker("Süzgeç", selection: $suzgec) {
                    ForEach(GorevSuzgec.allCases) { s in Text(s.rawValue).tag(s) }
                }
                .pickerStyle(.segmented)
            }

            ForEach(gruplar, id: \.gun) { grup in
                Section(gunEtiketi(grup.gun)) {
                    ForEach(grup.kayitlar) { g in
                        GorevSatiri(g: g,
                                    degistir: { vm.gorevDurumDegistir(g.id) },
                                    duzenle: { duzenlenecek = g })
                        .swipeActions(edge: .trailing) {
                            Button(role: .destructive) { vm.gorevSil(g.id) } label: {
                                Label("Sil", systemImage: "trash")
                            }
                        }
                        .swipeActions(edge: .leading) {
                            Button { vm.gorevDurumDegistir(g.id) } label: {
                                Label(g.tamamlandi ? "Geri Al" : "Tamamla",
                                      systemImage: g.tamamlandi ? "arrow.uturn.backward" : "checkmark")
                            }
                            .tint(g.tamamlandi ? .orange : .green)
                        }
                    }
                }
            }

            if gruplar.isEmpty {
                Section { Text("Bu süzgeçte kayıt yok.").foregroundStyle(.secondary) }
            }
        }
        .listStyle(.insetGrouped)
    }

    private func sayac(_ deger: String, _ baslik: String, _ renk: Color) -> some View {
        VStack(spacing: 2) {
            Text(deger).font(.title3).bold().foregroundStyle(renk)
            Text(baslik).font(.caption2).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Satır

struct GorevSatiri: View {
    let g: Gorev
    var degistir: () -> Void
    var duzenle: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Button(action: degistir) {
                Image(systemName: g.tamamlandi ? "checkmark.circle.fill" : "circle")
                    .font(.title2)
                    .foregroundStyle(g.tamamlandi ? Color.green : Color.secondary)
            }
            .buttonStyle(.plain)

            VStack(alignment: .leading, spacing: 4) {
                Text(g.metin)
                    .strikethrough(g.tamamlandi, color: .secondary)
                    .foregroundStyle(g.tamamlandi ? .secondary : .primary)
                HStack(spacing: 8) {
                    HStack(spacing: 3) {
                        Image(systemName: g.tur.simge)
                        Text(g.tur.durumYazisi(g.tamamlandi))
                    }
                    .font(.caption2).bold()
                    .padding(.horizontal, 7).padding(.vertical, 3)
                    .background(turRengi(g.tur).opacity(0.16),
                                in: Capsule())
                    .foregroundStyle(turRengi(g.tur))

                    Label(saatYazi(g.tarih), systemImage: "clock")
                        .font(.caption2).foregroundStyle(.secondary)
                }
            }
            Spacer(minLength: 0)
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
        .onTapGesture(perform: duzenle)
    }
}

// MARK: - Ekle / düzenle

struct GorevSheet: View {
    let vm: DepoVM
    var duzenle: Gorev? = nil

    @Environment(\.dismiss) private var kapat

    @State private var metin = ""
    @State private var tur: GorevTuru = .not
    @State private var tarih = Date()
    @State private var tamamlandi = false
    @State private var hazirlandi = false

    private var duzenleMi: Bool { duzenle != nil }
    private var gecerli: Bool { !metin.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }

    var body: some View {
        NavigationStack {
            Form {
                Section("Ne oldu / ne olacak?") {
                    TextField("Örn: Ahmet'ten 10 kutu alınacak", text: $metin, axis: .vertical)
                        .lineLimit(2...8)
                }

                Section("Tür") {
                    Picker("Tür", selection: $tur) {
                        ForEach(GorevTuru.allCases) { t in
                            Label(t.baslik, systemImage: t.simge).tag(t)
                        }
                    }
                    .pickerStyle(.menu)
                }

                Section("Tarih ve Saat") {
                    DatePicker("Zaman", selection: $tarih, displayedComponents: [.date, .hourAndMinute])
                        .environment(\.locale, trYerel)
                    HStack(spacing: 8) {
                        Button("Şimdi") { tarih = Date() }.buttonStyle(.bordered)
                        Button("Yarın") {
                            tarih = Calendar.current.date(byAdding: .day, value: 1, to: tarih) ?? tarih
                        }.buttonStyle(.bordered)
                        Button("Dün") {
                            tarih = Calendar.current.date(byAdding: .day, value: -1, to: tarih) ?? tarih
                        }.buttonStyle(.bordered)
                    }
                }

                Section("Durum") {
                    Toggle(tur.durumYazisi(tamamlandi), isOn: $tamamlandi)
                }

                if duzenleMi, let g = duzenle {
                    Section {
                        Button(role: .destructive) {
                            vm.gorevSil(g.id)
                            kapat()
                        } label: {
                            Label("Bu kaydı sil", systemImage: "trash")
                        }
                    }
                }
            }
            .navigationTitle(duzenleMi ? "Kaydı Düzenle" : "Yeni Kayıt")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("İptal") { kapat() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Kaydet") {
                        if let g = duzenle {
                            vm.gorevGuncelle(id: g.id, metin: metin, tur: tur, tarih: tarih, tamamlandi: tamamlandi)
                        } else {
                            vm.gorevEkle(metin: metin, tur: tur, tarih: tarih, tamamlandi: tamamlandi)
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
                if let g = duzenle {
                    metin = g.metin
                    tur = g.tur
                    tarih = g.tarih
                    tamamlandi = g.tamamlandi
                }
            }
        }
    }
}
