# FinVault - Self Finance Management

A modern, offline-first personal finance and expense tracking application built with **Flutter** and powered by a local reactive database. Track income, manage daily expenses, set category budgets, and visualize spending insights with clean analytics.

## Features

- **Transaction Management**: Quickly log daily income and expenses with customizable categories and payment methods.
- **Budgeting & Savings Goals**: Set monthly budgets and track real-time progress toward financial milestones.
- **Visual Analytics**: Interactive daily expense charts, category donut breakdowns, and monthly comparison graphs.
- **Insights Engine**: Automated spending summaries, period-over-period trends, and balance tracking.
- **Data Privacy & Backup**: Fully local storage with import/export backup functionality—no account required.
- **Modern UI**: Light/Dark mode support, fluid animations, and a responsive application shell.


## Tech Stack

| Layer | Technology |
| :--- | :--- |
| **Framework** | Flutter (Dart SDK) |
| **State Management** | Riverpod / Provider Architecture |
| **Local Database** | Drift / SQLite (Reactive offline storage) |
| **Charts** | Interactive charting widgets |
| **Platform** | Android, iOS, Web, Desktop |

---

## Project Structure

lib/
├── app.dart                    # Application configuration & root widget
├── main.dart                   # Entry point
├── core/
│   ├── constants/              # App icons, strings, and static assets
│   ├── database/               # Database tables, schemas, and seed data
│   ├── errors/                 # Global error handling and failures
│   ├── theme/                  # Colors, typography, and theme setup
│   └── utils/                  # Date helpers and currency formatters
├── features/
│   ├── add_transaction/        # Transaction creation & editing
│   ├── analytics/              # Visual financial reporting
│   ├── budgets/                # Budget planning and tracking
│   ├── dashboard/              # Home overview & metric cards
│   ├── goals/                  # Savings goals progress
│   ├── settings/               # Categories, payment methods & backup
│   ├── shell/                  # Navigation shell and bottom bar
│   └── transactions/           # Transaction listing & detail sheet
├── models/                     # Data transfer objects and domain models
├── providers/                  # State management providers
├── repositories/               # Data access abstraction layer
├── services/                   # Calculations, analytics & backup services
└── widgets/                    # Reusable cards, dialogs, charts & pickers



## Getting Started

### Prerequisites

* [Flutter SDK](https://docs.flutter.dev/get-started/install) (`>=3.0.0`)
* [Android Studio](https://developer.android.com/studio) or [VS Code](https://code.visualstudio.com/) with the Flutter extension installed

### Installation & Run

1. **Clone the repository:**
bash:
git clone [https://github.com/debbarmanshivam20-hue/selfFinance_management.git](https://github.com/debbarmanshivam20-hue/selfFinance_management.git)
cd selfFinance_management




2. **Install dependencies:**
bash:
flutter pub get


3. **Generate database code (if needed):**
bash:
dart run build_runner build --delete-conflicting-outputs



4. **Run the application:**
bash:
flutter run


## Contributing

Contributions are welcome! If you have suggestions or bug reports:

1. Fork the Project
2. Create your Feature Branch (`git checkout -b feature/AmazingFeature`)
3. Commit your Changes (`git commit -m "Add some AmazingFeature"`)
4. Push to the Branch (`git push origin feature/AmazingFeature`)
5. Open a Pull Request


## License

This project is licensed under the MIT License.


### How to update your GitHub repo with this README:

1. Create or overwrite the file `README.md` in your project folder with the content above.
2. Run the following commands in your terminal:
   ```powershell```
   git add README.md
   git commit -m "Add comprehensive project README"
   git push

```
