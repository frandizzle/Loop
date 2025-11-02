//
//  CLKComplicationTemplate.swift
//  Loop WatchApp Extension
//
//  Custom build with IOB displayed in complication
//

import ClockKit
import HealthKit
import LoopKit
import LoopCore
import UIKit

extension CLKComplicationTemplate {

    static func templateForFamily(
        _ family: CLKComplicationFamily,
        glucose: HKQuantity,
        unit: HKUnit,
        glucoseDate: Date?,
        trend: GlucoseTrend?,
        eventualGlucose: HKQuantity?,
        at date: Date,
        loopLastRunDate: Date?,
        recencyInterval: TimeInterval,
        chartGenerator makeChart: () -> UIImage?
    ) -> CLKComplicationTemplate? {

        let formatter = NumberFormatter.glucoseFormatter(for: unit)

        guard let glucoseDate = glucoseDate else {
            return nil
        }

        let glucoseString: String
        let trendString: String

        let isGlucoseStale = date.timeIntervalSince(glucoseDate) > recencyInterval

        if isGlucoseStale {
            glucoseString = NSLocalizedString("---", comment: "No glucose value representation")
            trendString = ""
        } else {
            guard let formattedGlucose = formatter.string(from: glucose.doubleValue(for: unit)) else {
                return nil
            }
            glucoseString = formattedGlucose
            trendString = trend?.symbol ?? " "
        }

        // --- Determine color freshness ---
        let loopCompletionFreshness = LoopCompletionFreshness(lastCompletion: loopLastRunDate, at: date)
        let tintColor: UIColor
        switch loopCompletionFreshness {
        case .fresh: tintColor = .tintColor
        case .aging: tintColor = .agingColor
        case .stale: tintColor = .staleColor
        }

        // --- Add IOB safely ---
        var iobString = ""
        if let iobValue = ExtensionDelegate.shared().loopManager.activeContext?.iob {
            iobString = String(format: "IOB %.1fU", iobValue)
        }

        // --- Time since last run (e.g., 4MIN) ---
        var timePlain = ""
        if let loopDate = loopLastRunDate {
            let mins = max(0, Int(date.timeIntervalSince(loopDate) / 60))
            timePlain = "\(mins)MIN"
        }

        // --- Build the full text, e.g. “10.6→4MIN  IOB 6.8U” ---
        var displayText = "\(glucoseString)\(trendString)"
        if !timePlain.isEmpty { displayText += "→\(timePlain)" }
        if !iobString.isEmpty { displayText += "  \(iobString)" }

        let glucoseAndTrendText = CLKSimpleTextProvider(text: displayText)
        glucoseAndTrendText.tintColor = tintColor

        // --- Complication family layouts ---
        switch family {

        case .graphicRectangular:
            if #available(watchOSApplicationExtension 5.0, *) {
                return CLKComplicationTemplateGraphicRectangularLargeImage(
                    textProvider: CLKSimpleTextProvider(text: displayText),
                    imageProvider: CLKFullColorImageProvider(fullColorImage: makeChart() ?? UIImage())
                )
            } else {
                return nil
            }

        case .utilitarianLarge:
            return CLKComplicationTemplateUtilitarianLargeFlat(
                textProvider: CLKSimpleTextProvider(text: displayText)
            )

        case .modularLarge:
            return CLKComplicationTemplateModularLargeTallBody(
                headerTextProvider: CLKSimpleTextProvider(text: timePlain),
                bodyTextProvider: glucoseAndTrendText
            )

        case .modularSmall:
            let t = CLKComplicationTemplateModularSmallStackText(
                line1TextProvider: glucoseAndTrendText,
                line2TextProvider: CLKSimpleTextProvider(text: timePlain)
            )
            t.highlightLine2 = true
            return t

        default:
            // Fallback for other styles
            return CLKComplicationTemplateUtilitarianSmallFlat(
                textProvider: CLKSimpleTextProvider(text: displayText)
            )
        }
    }
}
