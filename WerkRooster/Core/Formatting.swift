import Foundation
import SwiftUI

extension String {
    var hhmm: String {
        if count >= 5 { return String(prefix(5)) }
        return self
    }

    var formattedNotificationDate: String {
        let input = DateFormatter()
        input.dateFormat = "yyyy-MM-dd HH:mm:ss"
        if let date = input.date(from: self) {
            let output = DateFormatter()
            output.locale = Locale(identifier: "nl_NL")
            output.dateStyle = .medium
            output.timeStyle = .short
            return output.string(from: date)
        }
        return self
    }
}

extension Date {
    var monthTitle: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "nl_NL")
        formatter.dateFormat = "LLLL yyyy"
        return formatter.string(from: self).capitalized
    }

    var startOfMonth: Date {
        Calendar.current.date(from: Calendar.current.dateComponents([.year, .month], from: self)) ?? self
    }

    var endOfMonth: Date {
        let start = startOfMonth
        return Calendar.current.date(byAdding: DateComponents(month: 1, day: -1), to: start) ?? self
    }

    var daysInMonth: Int {
        Calendar.current.range(of: .day, in: .month, for: self)?.count ?? 30
    }

    var leadingWeekdayOffset: Int {
        let day = Calendar.current.component(.weekday, from: startOfMonth)
        return (day + 5) % 7
    }

    func dateFor(day: Int) -> Date {
        Calendar.current.date(byAdding: .day, value: day - 1, to: startOfMonth) ?? self
    }

    var isoDate: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        return formatter.string(from: self)
    }
}

struct MonthHeader: View {
    @Binding var monthDate: Date
    let onChange: (Date) -> Void

    var body: some View {
        HStack {
            Button {
                monthDate = Calendar.current.date(byAdding: .month, value: -1, to: monthDate) ?? monthDate
                onChange(monthDate)
            } label: {
                Image(systemName: "chevron.left")
            }
            Spacer()
            Text(monthDate.monthTitle)
                .font(.headline)
            Spacer()
            Button {
                monthDate = Calendar.current.date(byAdding: .month, value: 1, to: monthDate) ?? monthDate
                onChange(monthDate)
            } label: {
                Image(systemName: "chevron.right")
            }
        }
    }
}
