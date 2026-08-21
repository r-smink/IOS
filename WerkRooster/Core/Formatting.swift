import Foundation
import SwiftUI

extension String {
    var roundedTo30Min: String {
        let parts = split(separator: ":").map { Int($0) }
        guard parts.count == 2,
              let hours = parts[0], hours >= 0, hours < 24,
              let minutes = parts[1], minutes >= 0, minutes < 60 else {
            return self
        }
        let totalMinutes = hours * 60 + minutes
        let rounded = ((totalMinutes + 15) / 30) * 30 % (24 * 60)
        let newHours = rounded / 60
        let newMinutes = rounded % 60
        return String(format: "%02d:%02d", newHours, newMinutes)
    }

    var toMonthStart: String? {
        return self + "-01"
    }

    var toMonthEnd: String? {
        let parts = split(separator: "-")
        guard parts.count == 2,
              let year = Int(parts[0]),
              let month = Int(parts[1]),
              let date = Calendar.current.date(from: DateComponents(year: year, month: month)) else {
            return nil
        }
        let range = Calendar.current.range(of: .day, in: .month, for: date)
        guard let lastDay = range?.last else { return nil }
        return String(format: "%04d-%02d-%02d", year, month, lastDay)
    }

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
