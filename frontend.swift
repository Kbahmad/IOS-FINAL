import SwiftUI
import CoreData

@objc(Item)
public class Item: NSManagedObject, Identifiable, Encodable {
    @NSManaged public var id: UUID?
    @NSManaged public var timestamp: Date?
    @NSManaged public var amount: Double
    @NSManaged public var category: String?
    @NSManaged public var notes: String?

    enum CodingKeys: CodingKey {
        case id, timestamp, amount, category, notes
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(timestamp, forKey: .timestamp)
        try container.encode(amount, forKey: .amount)
        try container.encode(category, forKey: .category)
        try container.encode(notes, forKey: .notes)
    }

}

extension Item {
    static func fetchRequest() -> NSFetchRequest<Item> {
        let request = NSFetchRequest<Item>(entityName: "Item")
        request.sortDescriptors = [NSSortDescriptor(keyPath: \Item.timestamp, ascending: true)]
        return request
    }
}

@objc(User)
public class User: NSManagedObject {
    @NSManaged public var username: String?
    @NSManaged public var password: String?
    @NSManaged public var email: String?
}

class PersistenceController {
    static let shared = PersistenceController()
    let container: NSPersistentContainer

    init() {
        container = NSPersistentContainer(name: "CashMind")

        let description = NSPersistentStoreDescription()

        if ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1" {
            description.url = URL(fileURLWithPath: "/dev/null")
        } else {
            description.type = NSInMemoryStoreType
        }

        container.persistentStoreDescriptions = [description]

        container.loadPersistentStores { _, error in
            if let error = error as NSError? {
                print("Unresolved error \(error), \(error.userInfo)")
            } else {
                print("Core Data Store Loaded Successfully")
            }
        }
    }

    var viewContext: NSManagedObjectContext {
        return container.viewContext
    }

    func saveContext() {
        let context = container.viewContext
        if context.hasChanges {
            do {
                try context.save()
                print(" Data saved successfully")
            } catch {
                let nsError = error as NSError
                fatalError(" Unresolved error \(nsError), \(nsError.userInfo)")
            }
        }
    }

    func fetchItems() -> [Item] {
        let request: NSFetchRequest<Item> = Item.fetchRequest()
        do {
            return try container.viewContext.fetch(request)
        } catch {
            print("Failed to fetch items: \(error)")
            return []
        }
    }

    func fetchUsers() -> [User] {
        let request: NSFetchRequest<User> = NSFetchRequest<User>(entityName: "User")
        do {
            return try container.viewContext.fetch(request)
        } catch {
            print("Failed to fetch users: \(error)")
            return []
        }
    }
}

import Foundation

class APIService {
    static let shared = APIService()
    private let baseURL = "https://your-api-endpoint.com"

    func fetchUserProfile(completion: @escaping (UserProfile?) -> Void) {
        guard let url = URL(string: "\(baseURL)/userProfile") else { return }

        URLSession.shared.dataTask(with: url) { data, response, error in
            guard let data = data, error == nil else {
                print(" Error fetching profile: \(error?.localizedDescription ?? "Unknown error")")
                completion(nil)
                return
            }
            do {
                let profile = try JSONDecoder().decode(UserProfile.self, from: data)
                completion(profile)
            } catch {
                print(" Decoding error: \(error)")
                completion(nil)
            }
        }.resume()
    }

    func authenticate(username: String, password: String, completion: @escaping (Bool) -> Void) {
        guard let url = URL(string: "\(baseURL)/authenticate") else {
            completion(false)
            return
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let payload = ["username": username, "password": password]
        do {
            let jsonData = try JSONSerialization.data(withJSONObject: payload)
            request.httpBody = jsonData
        } catch {
            completion(false)
            return
        }
        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                print(" Authentication error: \(error)")
                completion(false)
            } else if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 {
                completion(true)
            } else {
                completion(false)
            }
        }.resume()
    }

    func signUp(username: String, password: String, completion: @escaping (Bool) -> Void) {
        guard let url = URL(string: "\(baseURL)/signup") else {
            completion(false)
            return
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let payload = ["username": username, "password": password]
        do {
            let jsonData = try JSONSerialization.data(withJSONObject: payload)
            request.httpBody = jsonData
        } catch {
            completion(false)
            return
        }
        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                print(" Signup error: \(error)")
                completion(false)
            } else if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 201 {
                completion(true)
            } else {
                completion(false)
            }
        }.resume()
    }

    func syncExpenses(expenses: [Item], completion: @escaping (Bool) -> Void) {
        guard let url = URL(string: "\(baseURL)/syncExpenses") else { return }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        do {
            let jsonData = try JSONEncoder().encode(expenses)
            request.httpBody = jsonData
        } catch {
            print(" Encoding error: \(error)")
            completion(false)
            return
        }

        URLSession.shared.dataTask(with: request) { _, response, error in
            if let error = error {
                print(" Sync error: \(error)")
                completion(false)
            } else {
                completion(true)
            }
        }.resume()
    }
}

struct ContentView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @State private var isAuthenticated = false
    @State private var selectedTab = 0
    @State private var monthlyIncome: String = "5000"

    var body: some View {
        if isAuthenticated {
            TabView(selection: $selectedTab) {
                DashboardView()
                    .tabItem {
                        Label("Dashboard", systemImage: "house.fill")
                    }.tag(0)

                ExpenseView()
                    .tabItem {
                        Label("Expenses", systemImage: "list.bullet")
                    }.tag(1)

                BudgetView(monthlyIncome: $monthlyIncome)
                    .tabItem {
                        Label("Budget", systemImage: "chart.pie.fill")
                    }.tag(2)

                AnalyticsView()
                    .tabItem {
                        Label("Analytics", systemImage: "chart.bar.fill")
                    }.tag(3)

                SettingsView(isAuthenticated: $isAuthenticated)
                    .tabItem {
                        Label("Settings", systemImage: "gearshape.fill")
                    }.tag(4)
            }
        } else {
            AuthenticationView(isAuthenticated: $isAuthenticated)
        }
    }
}

struct AuthenticationView: View {
    @Binding var isAuthenticated: Bool
    @State private var username = ""
    @State private var password = ""
    @State private var email = ""
    @State private var isSigningUp = false
    @State private var showLoginFields = false
    @State private var errorMessage = ""
    @Environment(\.managedObjectContext) private var viewContext

    var body: some View {
        VStack {
            Text("CashMind")
                .font(.largeTitle)
                .bold()
                .padding()

            if isSigningUp || showLoginFields {
                TextField("Username", text: $username)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .padding()

                SecureField("Password", text: $password)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .padding()
                if isSigningUp {
                    TextField("Email", text: $email)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .padding()
                }

                if isSigningUp {
                    Button("Create Account") {
                        signUp()
                    }
                    .padding()
                    .background(Color.green)
                    .foregroundColor(.white)
                    .cornerRadius(10)

                    Button("Back to Sign In") {
                        isSigningUp = false
                    }
                    .padding()
                } else {
                    Button("Confirm Sign In") {
                        authenticateUser()
                    }
                    .padding()
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(10)
                }
            } else {
                Button("Sign In with Face ID / Touch ID") {
                    showLoginFields = true
                }
                .padding()
                .background(Color.blue)
                .foregroundColor(.white)
                .cornerRadius(10)
            }

            if !isSigningUp && !showLoginFields {
                Button("Sign Up") {
                    isSigningUp = true
                }
                .padding()
                .background(Color.green)
                .foregroundColor(.white)
                .cornerRadius(10)
            }

            if !errorMessage.isEmpty {
                Text(errorMessage)
                    .foregroundColor(.red)
            }
        }
    }

    private func authenticateUser() {
        if username.isEmpty || password.isEmpty {
            errorMessage = "Please enter both username and password."
        } else {
            APIService.shared.authenticate(username: username, password: password) { success in
                DispatchQueue.main.async {
                    if success {
                        isAuthenticated = true
                    } else {
                        errorMessage = "Authentication failed. Please check your credentials."
                    }
                }
            }
        }
    }

    private func signUp() {
        if username.isEmpty || password.isEmpty || email.isEmpty {
            errorMessage = "Please fill all fields."
        } else {

            let newUser = User(context: viewContext)
            newUser.username = username
            newUser.password = password
            newUser.email = email

            do {
                try viewContext.save()
                isAuthenticated = true
            } catch {
                errorMessage = "Failed to sign up: \(error.localizedDescription)"
            }
        }
    }
}

struct DashboardView: View {
    @State private var totalIncome: Double = 5000.0
    @State private var totalExpenses: Double = 3000.0
    @State private var remainingBudget: Double = 2000.0

    var body: some View {
        VStack {
            Text("Dashboard")
                .font(.largeTitle)
                .bold()
                .padding()

            Text("Your Monthly Budget Overview")
                .font(.headline)
                .padding()

            VStack(alignment: .leading) {
                HStack {
                    Text("Total Income: ")
                        .fontWeight(.bold)
                    Spacer()
                    Text("$\(totalIncome, specifier: "%.2f")")
                        .foregroundColor(.green)
                }
                .padding()

                HStack {
                    Text("Total Expenses: ")
                        .fontWeight(.bold)
                    Spacer()
                    Text("$\(totalExpenses, specifier: "%.2f")")
                        .foregroundColor(.red)
                }
                .padding()

                HStack {
                    Text("Remaining Budget: ")
                        .fontWeight(.bold)
                    Spacer()
                    Text("$\(remainingBudget, specifier: "%.2f")")
                        .foregroundColor(remainingBudget >= 0 ? .green : .red)
                }
                .padding()
            }

            Spacer()
        }
    }
}

struct ExpenseView: View {
    @FetchRequest(
        entity: Item.entity(),
        sortDescriptors: [NSSortDescriptor(keyPath: \Item.timestamp, ascending: true)]
    ) private var items: FetchedResults<Item>

    @Environment(\.managedObjectContext) private var viewContext
    @State private var amount: String = ""
    @State private var category: String = ""
    @State private var notes: String = ""
    private let predefinedCategories = ["Food", "Transport", "Entertainment", "Rent", "Shopping", "Bills"]

    var body: some View {
        VStack {
            Text("Expenses")
                .font(.largeTitle)
                .bold()
                .padding()

            List {
                if items.isEmpty {
                    Text("No expenses recorded")
                        .foregroundColor(.gray)
                } else {
                    ForEach(items) { item in
                        HStack {
                            VStack(alignment: .leading) {
                                Text("\(item.category ?? "Unknown") - \(item.amount, specifier: "%.2f")")
                                    .fontWeight(.bold)
                                Text(item.notes ?? "No notes")
                                    .font(.subheadline)
                                    .foregroundColor(.gray)
                            }
                            Spacer()
                            Button(action: {
                                viewContext.delete(item)
                                PersistenceController.shared.saveContext()
                            }) {
                                Image(systemName: "trash")
                                    .foregroundColor(.red)
                            }
                        }
                    }
                    .onDelete(perform: deleteItems)
                }
            }

            TextField("Amount", text: $amount)
                .keyboardType(.decimalPad)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .padding()

            Picker("Category", selection: $category) {
                ForEach(predefinedCategories, id: \.self) { category in
                    Text(category).tag(category)
                }
                Text("Custom").tag("Custom")
            }
            .pickerStyle(MenuPickerStyle())
            .padding()

            if category == "Custom" {
                TextField("Custom Category", text: $category)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .padding()
            }

            TextField("Notes", text: $notes)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .padding()

            Button(action: addItem) {
                Label("Add Expense", systemImage: "plus")
            }
            .padding()
            .background(Color.blue)
            .foregroundColor(.white)
            .cornerRadius(10)

            Button("Sync Expenses") {
                let expenses = PersistenceController.shared.fetchItems()
                APIService.shared.syncExpenses(expenses: expenses) { success in
                    DispatchQueue.main.async {
                        if success {
                            print("Expenses synced successfully")
                        } else {
                            print("Failed to sync expenses")
                        }
                    }
                }
            }
            .padding()
            .background(Color.green)
            .foregroundColor(.white)
            .cornerRadius(10)
        }
        .onAppear {
            if items.isEmpty {
                addExampleExpenses()
            }
        }
    }

    private func addItem() {
        guard let amountValue = Double(amount) else { return }
        let newItem = Item(context: viewContext)
        newItem.id = UUID()
        newItem.timestamp = Date()
        newItem.amount = amountValue
        newItem.category = category
        newItem.notes = notes
        PersistenceController.shared.saveContext()
        resetFields()
    }

    private func deleteItems(offsets: IndexSet) {
        withAnimation {
            offsets.map { items[$0] }.forEach(viewContext.delete)
            PersistenceController.shared.saveContext()
        }
    }

    private func resetFields() {
        amount = ""
        category = ""
        notes = ""
    }

    private func addExampleExpenses() {

        let foodExpense = (category: "Food", amount: 150.0, notes: "Grocery shopping")
        let transportExpense = (category: "Transport", amount: 50.0, notes: "Bus fare")
        let entertainmentExpense = (category: "Entertainment", amount: 200.0, notes: "Movie tickets")
        let rentExpense = (category: "Rent", amount: 1200.0, notes: "Monthly rent")
        let billsExpense = (category: "Bills", amount: 300.0, notes: "Electricity and water bill")

        let exampleExpenses = [foodExpense, transportExpense, entertainmentExpense, rentExpense, billsExpense]

        for expense in exampleExpenses {
            let newItem = Item(context: viewContext)
            newItem.id = UUID()
            newItem.timestamp = Date()
            newItem.amount = expense.amount
            newItem.category = expense.category
            newItem.notes = expense.notes
        }

        PersistenceController.shared.saveContext()
    }
}

struct BudgetView: View {
    @Binding var monthlyIncome: String
    @State private var rentBudget: String = ""
    @State private var foodBudget: String = ""
    @State private var transportBudget: String = ""
    @State private var entertainmentBudget: String = ""
    @State private var allocatedBudget: Double = 0.0
    @State private var totalBudget: Double = 0.0
    @State private var remainingBudget: Double = 0.0

    var body: some View {
        VStack {
            Text("Budget Planner")
                .font(.largeTitle)
                .bold()
                .padding()

            Text("Monthly Income: $\(monthlyIncome)")
                .padding()

            TextField("Rent Budget", text: $rentBudget)
                .keyboardType(.decimalPad)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .padding()

            TextField("Food Budget", text: $foodBudget)
                .keyboardType(.decimalPad)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .padding()

            TextField("Transport Budget", text: $transportBudget)
                .keyboardType(.decimalPad)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .padding()

            TextField("Entertainment Budget", text: $entertainmentBudget)
                .keyboardType(.decimalPad)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .padding()

            Button("Set Budget") {
                calculateBudget()
            }
            .padding()
            .background(Color.blue)
            .foregroundColor(.white)
            .cornerRadius(10)

            VStack(alignment: .leading) {
                Text("Total Budget: $\(totalBudget, specifier: "%.2f")")
                    .fontWeight(.bold)
                Text("Allocated Budget: $\(allocatedBudget, specifier: "%.2f")")
                    .fontWeight(.bold)
                Text("Remaining Budget: $\(remainingBudget, specifier: "%.2f")")
                    .foregroundColor(remainingBudget >= 0 ? .green : .red)
                    .fontWeight(.bold)
            }
            .padding()

            Spacer()
        }
    }

    private func calculateBudget() {
        guard let rent = Double(rentBudget),
              let food = Double(foodBudget),
              let transport = Double(transportBudget),
              let entertainment = Double(entertainmentBudget) else {
            return
        }

        allocatedBudget = rent + food + transport + entertainment
        totalBudget = Double(monthlyIncome) ?? 0.0
        remainingBudget = totalBudget - allocatedBudget
    }
}

struct AnalyticsView: View {
    @State private var spendingData: [String: Double] = [
        "Food": 300.0,
        "Transport": 150.0,
        "Entertainment": 200.0,
        "Rent": 1200.0,
        "Bills": 250.0
    ]

    var body: some View {
        VStack {
            Text("Analytics")
                .font(.largeTitle)
                .bold()
                .padding()

            Text("Visualize your spending trends")
                .font(.headline)
                .padding()

            VStack(alignment: .leading) {
                ForEach(spendingData.keys.sorted(), id: \.self) { category in
                    HStack {
                        Text(category)
                            .fontWeight(.bold)
                        Spacer()
                        Text("$\(spendingData[category]!, specifier: "%.2f")")
                    }
                    .padding()
                }
            }

            Spacer()
        }
    }
}

struct SettingsView: View {
    @Binding var isAuthenticated: Bool
    @State private var username: String = "John Doe"
    @State private var email: String = "john.doe@example.com"
    @State private var monthlyIncome: String = "5000"
    @State private var preferredCurrency: String = "USD"
    @State private var selectedTheme: ColorScheme = .light
    @State private var selectedFontSize: CGFloat = 14

    var body: some View {
        VStack {
            Text("Settings")
                .font(.largeTitle)
                .bold()
                .padding()

            Form {
                Section(header: Text("User Profile")) {
                    HStack {
                        Text("Username:")
                        Spacer()
                        TextField("Enter Name", text: $username)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                    }

                    HStack {
                        Text("Email:")
                        Spacer()
                        TextField("Enter Email", text: $email)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                    }

                    HStack {
                        Text("Monthly Income:")
                        Spacer()
                        TextField("Enter Income", text: $monthlyIncome)
                            .keyboardType(.decimalPad)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                    }

                    HStack {
                        Text("Preferred Currency:")
                        Spacer()
                        TextField("Enter Currency", text: $preferredCurrency)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                    }
                }

                Section(header: Text("Theme Settings")) {
                    Picker("Theme", selection: $selectedTheme) {
                        Text("Light").tag(ColorScheme.light)
                        Text("Dark").tag(ColorScheme.dark)
                    }
                    .pickerStyle(SegmentedPickerStyle())

                    Slider(value: $selectedFontSize, in: 10...20, step: 1) {
                        Text("Font Size")
                    }
                }

                Section {
                    Button("Log Out") {
                        isAuthenticated = false
                        print("User logged out")
                    }
                    .foregroundColor(.red)
                }
            }
            .padding()

            Spacer()
        }
        .preferredColorScheme(selectedTheme)
    }
}

private let itemFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.dateStyle = .short
    formatter.timeStyle = .medium
    return formatter
}()

#Preview {
    ContentView()
}
@main
struct CashMindApp: App {
    let persistenceController = PersistenceController.shared

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.managedObjectContext, persistenceController.container.viewContext)
        }
    }
}
struct UserProfile: Codable {
    let id: UUID
    let name: String
    let email: String
}
