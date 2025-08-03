//
//  ContentView.swift
//  authenticly
//
//  Created by Armaan Agrawal on 8/2/25.
//

import SwiftUI
import SwiftData
import UIKit



extension ColorScheme: RawRepresentable {
    public var rawValue: String {
        switch self {
        case .light: return "light"
        case .dark: return "dark"
        @unknown default: return "light"
        }
    }
    
    public init?(rawValue: String) {
        switch rawValue {
        case "light": self = .light
        case "dark": self = .dark
        default: self = .light
        }
    }
}

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \JournalEntry.timestamp, order: .reverse) private var entries: [JournalEntry]
    
    // API Integration
    @StateObject private var apiClient = APIClient.shared
    @StateObject private var syncService = SyncService.shared
    
    @State private var currentEntry: JournalEntry?
    @State private var text: String = ""
    @State private var selectedFont: String = "Lato-Regular"
    @State private var fontSize: CGFloat = 16
    @State private var timeRemaining: Int = 900 // 15 minutes
    @State private var timerIsRunning = false
    @State private var showingHistory = false
    @State private var showingSettings = false
    @State private var showingChatMenu = false
    @State private var showingAIAnalysis = false
    @State private var aiAnalysisText = ""
    @State private var isAnalyzing = false
    @AppStorage("colorScheme") private var colorScheme: ColorScheme = .light
    @State private var placeholderText: String = ""
    @State private var didCopyPrompt: Bool = false
    
    let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
    let availableFonts = ["Lato-Regular", "Arial", "Times New Roman", "Helvetica", "Georgia"]
    let fontSizes: [CGFloat] = [14, 16, 18, 20, 22, 24]
    
    let placeholderOptions = [
        "Begin writing",
        "Pick a thought and go",
        "Start typing",
        "What's on your mind",
        "Just start",
        "Type your first thought",
        "Start with one sentence",
        "Just say it"
    ]
    
    // AI Chat Prompts
    private let aiChatPrompt = """
    below is my journal entry. wyt? talk through it with me like a friend. don't therpaize me and give me a whole breakdown, don't repeat my thoughts with headings. really take all of this, and tell me back stuff truly as if you're an old homie.
    
    Keep it casual, dont say yo, help me make new connections i don't see, comfort, validate, challenge, all of it. dont be afraid to say a lot. format with markdown headings if needed.

    do not just go through every single thing i say, and say it back to me. you need to proccess everythikng is say, make connections i don't see it, and deliver it all back to me as a story that makes me feel what you think i wanna feel. thats what the best therapists do.

    ideally, you're style/tone should sound like the user themselves. it's as if the user is hearing their own tone but it should still feel different, because you have different things to say and don't just repeat back they say.

    else, start by saying, "hey, thanks for showing me this. my thoughts:"
        
    my entry:
    """

    var body: some View {
        NavigationView {
            ZStack {
                Color(colorScheme == .dark ? Color(white: 0.1) : .white)
                    .ignoresSafeArea()

                VStack(spacing: 0) {
                    topNavBar
                    
                    mainTextEditor()
                        .frame(maxHeight: .infinity)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .navigationBarHidden(true)
            .onAppear {
                setupInitialState()
                syncService.configure(with: modelContext)
                Task {
                    await syncService.performFullSync()
                }
            }
            .onReceive(timer) { _ in
                if timerIsRunning && timeRemaining > 0 {
                    timeRemaining -= 1
                } else if timeRemaining == 0 {
                    timerIsRunning = false
                }
            }
            .onChange(of: text) { newValue in
                saveCurrentEntry()
            }
            .sheet(isPresented: $showingHistory) {
                HistoryView(entries: entries, currentEntry: $currentEntry, text: $text)
                    .environmentObject(EntryManager(modelContext: modelContext))
                    .preferredColorScheme(colorScheme)
            }
            .sheet(isPresented: $showingSettings) {
                SettingsView(
                    selectedFont: $selectedFont,
                    fontSize: $fontSize,
                    colorScheme: $colorScheme,
                    availableFonts: availableFonts,
                    fontSizes: fontSizes
                )
                .preferredColorScheme(colorScheme)
            }
            .confirmationDialog("Chat with AI", isPresented: $showingChatMenu, titleVisibility: .visible) {
                Button("AI Analysis") {
                    analyzeWithGemini()
                }
                Button("ChatGPT") {
                    openChatGPT()
                }
                Button("Claude") {
                    openClaude()
                }
                Button("Copy Prompt") {
                    copyPromptToClipboard()
                }
                Button("Cancel", role: .cancel) { }
            } message: {
                Text("Choose your AI assistant")
            }
            .sheet(isPresented: $showingAIAnalysis) {
                AIAnalysisView(
                    analysisText: aiAnalysisText,
                    isAnalyzing: isAnalyzing,
                    onDismiss: { showingAIAnalysis = false }
                )
            }
        }
        .preferredColorScheme(colorScheme)
    }
    
    private var topNavBar: some View {
        HStack(spacing: 10) {
            Button(action: {
                showingHistory = true
            }) {
                Image(systemName: "clock.arrow.circlepath")
                    .font(.system(size: 16))
            }
            
            Button(action: {
                createNewEntry()
            }) {
                Image(systemName: "plus.circle")
                    .font(.system(size: 16))
            }
            
            Button(action: {
                showingChatMenu = true
            }) {
                Image(systemName: "bubble.left.and.bubble.right")
                    .font(.system(size: 16))
            }
            .disabled(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            
            Spacer()
            
            Button(action: {
                timerIsRunning.toggle()
            }) {
                HStack(spacing: 8) {
                    Image(systemName: timerIsRunning ? "pause.circle.fill" : "play.circle.fill")
                        .font(.system(size: 16))
                    
                    Text(timerButtonTitle)
                        .font(.system(size: 14, weight: .medium, design: .monospaced))
                }
            }
            .onLongPressGesture {
                timeRemaining = 900
                timerIsRunning = false
            }
            .gesture(
                DragGesture(minimumDistance: 30)
                    .onEnded { value in
                        if !timerIsRunning {
                            let verticalMovement = value.translation.height
                            if abs(verticalMovement) > 20 {
                                let adjustment = Int(-verticalMovement / 10) * 60
                                timeRemaining = max(300, min(3600, timeRemaining + adjustment))
                            }
                        }
                    }
            )
            
            Button(action: {
                showingSettings = true
            }) {
                Image(systemName: "gear")
                    .font(.system(size: 16))
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 6)
        .background(navBarMaterial.ignoresSafeArea(edges: .top))
        .foregroundColor(colorScheme == .dark ? .white : .primary)
    }
    
    @ViewBuilder
    private var navBarMaterial: some View {
        if colorScheme == .dark {
            Color.black
        } else {
            Color.clear.background(Material.ultraThinMaterial)
        }
    }
    
    private func mainTextEditor() -> some View {
        ZStack(alignment: .topLeading) {
            TextEditor(text: $text)
                .foregroundColor(colorScheme == .dark ? .white : .black)
                .font(.custom(selectedFont, size: fontSize))
                .lineSpacing(4)
                .padding(.horizontal, 16)
                .padding(.vertical, 16)
                .background(Color.clear)
                .scrollContentBackground(.hidden)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .toolbar {
                    ToolbarItemGroup(placement: .keyboard) {
                        Spacer()
                        Button("Done") {
                            hideKeyboard()
                        }
                    }
                }
            
            // Placeholder text
            if text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                Text(placeholderText)
                    .font(.custom(selectedFont, size: fontSize))
                    .foregroundColor(.secondary.opacity(0.5))
                    .padding(.horizontal, 20)
                    .padding(.vertical, 24)
                    .allowsHitTesting(false)
                    .multilineTextAlignment(.leading)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private func hideKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
    
    private var timerButtonTitle: String {
        if !timerIsRunning && timeRemaining == 900 {
            return "15:00"
        }
        let minutes = timeRemaining / 60
        let seconds = timeRemaining % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
    
    // MARK: - Methods
    
    private func setupInitialState() {
        placeholderText = placeholderOptions.randomElement() ?? "Begin writing"
        
        if let mostRecentEntry = entries.first {
            currentEntry = mostRecentEntry
            text = mostRecentEntry.content
        } else {
            createWelcomeEntry()
        }
    }
    
    private func createNewEntry() {
        // Save current entry first
        saveCurrentEntry()
        
        // Create new entry
        let newEntry = JournalEntry.createNew()
        modelContext.insert(newEntry)
        
        // Set as current
        currentEntry = newEntry
        text = ""
        placeholderText = placeholderOptions.randomElement() ?? "Begin writing"
        
        // Save the model context
        try? modelContext.save()
    }
    
    private func createWelcomeEntry() {
        let welcomeEntry = JournalEntry.createNew()
        
        // Load welcome message from default.md
        if let defaultMessageURL = Bundle.main.url(forResource: "default", withExtension: "md"),
           let defaultMessage = try? String(contentsOf: defaultMessageURL, encoding: .utf8) {
            welcomeEntry.content = defaultMessage
            text = defaultMessage
        } else {
            welcomeEntry.content = "Welcome to Freewrite!\n\nThis is your space for stream-of-consciousness writing. Set a timer, start typing, and let your thoughts flow freely."
            text = welcomeEntry.content
        }
        
        welcomeEntry.updatePreviewText()
        modelContext.insert(welcomeEntry)
        currentEntry = welcomeEntry
        
        try? modelContext.save()
    }
    
    private func saveCurrentEntry() {
        guard let entry = currentEntry else { return }
        entry.content = text
        entry.updatePreviewText()
        entry.markForSync()
        try? modelContext.save()
        
        // Sync to backend if connected
        Task {
            await syncService.syncSingleEntry(entry)
        }
    }
    
    private func openChatGPT() {
        let trimmedText = text.trimmingCharacters(in: .whitespacesAndNewlines)
        let fullText = aiChatPrompt + "\n\n" + trimmedText
        
        if let encodedText = fullText.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
           let url = URL(string: "https://chat.openai.com/?m=" + encodedText) {
            UIApplication.shared.open(url)
        }
    }
    
    private func openClaude() {
        let trimmedText = text.trimmingCharacters(in: .whitespacesAndNewlines)
        let fullText = aiChatPrompt + "\n\n" + trimmedText
        
        if let encodedText = fullText.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
           let url = URL(string: "https://claude.ai/new?q=" + encodedText) {
            UIApplication.shared.open(url)
        }
    }
    
    private func copyPromptToClipboard() {
        let trimmedText = text.trimmingCharacters(in: .whitespacesAndNewlines)
        let fullText = aiChatPrompt + "\n\n" + trimmedText
        
        UIPasteboard.general.string = fullText
        didCopyPrompt = true
    }
    

}

// MARK: - History View
struct HistoryView: View {
    let entries: [JournalEntry]
    @Binding var currentEntry: JournalEntry?
    @Binding var text: String
    @EnvironmentObject var entryManager: EntryManager
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationView {
            List {
                ForEach(entries) { entry in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(entry.previewText.isEmpty ? "Empty entry" : entry.previewText)
                            .font(.body)
                            .lineLimit(2)
                        
                        Text(entry.date)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding(.vertical, 4)
                    .onTapGesture {
                        currentEntry = entry
                        text = entry.content
                        dismiss()
                    }
                }
                .onDelete(perform: deleteEntries)
            }
            .navigationTitle("History")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
    
    private func deleteEntries(offsets: IndexSet) {
        withAnimation {
            for index in offsets {
                entryManager.deleteEntry(entries[index])
            }
        }
    }
}

// MARK: - Settings View
struct SettingsView: View {
    @Binding var selectedFont: String
    @Binding var fontSize: CGFloat
    @Binding var colorScheme: ColorScheme
    let availableFonts: [String]
    let fontSizes: [CGFloat]
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            Form {
                Section("Font") {
                    Picker("Font Family", selection: $selectedFont) {
                        ForEach(availableFonts, id: \.self) { font in
                            Text(font).tag(font)
                        }
                    }
                    
                    Picker("Font Size", selection: $fontSize) {
                        ForEach(fontSizes, id: \.self) { size in
                            Text("\(Int(size))px").tag(size)
                        }
                    }
                }
                
                Section("Appearance") {
                    Picker("Theme", selection: $colorScheme) {
                        Text("Light").tag(ColorScheme.light)
                        Text("Dark").tag(ColorScheme.dark)
                    }
                    .pickerStyle(SegmentedPickerStyle())
                }
                
                Section("About") {
                    Text("Freewrite helps you practice stream-of-consciousness writing. Set a timer, start typing, and let your thoughts flow freely.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
    
    // MARK: - AI Analysis
    
    private func analyzeWithGemini() {
        guard let entry = currentEntry else { return }
        
        isAnalyzing = true
        aiAnalysisText = ""
        showingAIAnalysis = true
        
        Task {
            do {
                let analysis = try await apiClient.analyzeJournal(
                    entryId: entry.id.uuidString,
                    analysisType: "general"
                )
                
                await MainActor.run {
                    aiAnalysisText = analysis.analysis
                    isAnalyzing = false
                }
            } catch {
                await MainActor.run {
                    aiAnalysisText = "Failed to analyze: \(error.localizedDescription)\n\nMake sure the backend is running and properly configured with Google Gemini API key."
                    isAnalyzing = false
                }
            }
        }
    }
}

// MARK: - AI Analysis View

struct AIAnalysisView: View {
    let analysisText: String
    let isAnalyzing: Bool
    let onDismiss: () -> Void
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    if isAnalyzing {
                        VStack(spacing: 16) {
                            ProgressView()
                                .scaleEffect(1.2)
                            Text("Analyzing your journal entry...")
                                .font(.title3)
                                .foregroundColor(.secondary)
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else {
                        Text(analysisText)
                            .font(.body)
                            .lineSpacing(4)
                            .padding()
                    }
                }
            }
            .navigationTitle("AI Analysis")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        onDismiss()
                    }
                }
            }
        }
    }
}

// MARK: - Entry Manager
class EntryManager: ObservableObject {
    private let modelContext: ModelContext
    
    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }
    
    func deleteEntry(_ entry: JournalEntry) {
        modelContext.delete(entry)
        try? modelContext.save()
    }
}

#Preview {
    ContentView()
        .modelContainer(for: JournalEntry.self, inMemory: true)
}
