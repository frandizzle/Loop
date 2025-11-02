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
        glucoseString = NSLocalizedString("---", comment: "No glucose value representation (3 dashes for mg/dL)")
        trendString = ""
    } else {
        guard let formattedGlucose = formatter.string(from: glucose.doubleValue(for: unit)) else {
            return nil
        }
        glucoseString = formattedGlucose
        trendString = trend?.symbol ?? " "
    }
    
    let loopCompletionFreshness = LoopCompletionFreshness(lastCompletion: loopLastRunDate, at: date)
    
    let tintColor: UIColor
    switch loopCompletionFreshness {
    case .fresh:
        tintColor = .tintColor
    case .aging:
        tintColor = .agingColor
    case .stale:
        tintColor = .staleColor
    }

    // --- Add IOB support safely ---
    var accessibilityStrings = [glucoseString]
    if let trend = trend {
        accessibilityStrings.append(trend.localizedDescription)
    }

    var iobString = ""
    if let iobValue = LoopDataManager.shared?.activeContext?.iob?.value {
        iobString = String(format: "IOB %.1fU", iobValue)
    }

    // Make a readable "xMIN" time string
    var timePlain = ""
    if let loopDate = loopLastRunDate {
        let mins = max(0, Int(date.timeIntervalSince(loopDate) / 60))
        timePlain = "\(mins)MIN"
    }

    // Build the full display text
    var displayText = "\(glucoseString)\(trendString)"
    if !timePlain.isEmpty {
        displayText += "→\(timePlain)"
    }
    if !iobString.isEmpty {
        displayText += "  \(iobString)"
        accessibilityStrings.append(iobString)
    }

    let glucoseAndTrendText = CLKSimpleTextProvider(
        text: displayText,
        shortText: glucoseString,
        accessibilityLabel: accessibilityStrings.joined(separator: ", ")
    )

    let timeFormatter = DateFormatter()
    timeFormatter.dateStyle = .none
    timeFormatter.timeStyle = .short

    // --- Complication Families ---
    switch family {
    case .modularSmall:
        let template = CLKComplicationTemplateModularSmallStackText(line1TextProvider: glucoseAndTrendText,
                                                                    line2TextProvider: CLKSimpleTextProvider(text: timePlain))
        template.highlightLine2 = true
        return template
    case .modularLarge:
        return CLKComplicationTemplateModularLargeTallBody(headerTextProvider: CLKSimpleTextProvider(text: timePlain),
                                                           bodyTextProvider: glucoseAndTrendText)
    case .circularSmall:
        return CLKComplicationTemplateCircularSmallSimpleText(textProvider: CLKSimpleTextProvider(text: glucoseString))
    case .extraLarge:
        return CLKComplicationTemplateExtraLargeStackText(line1TextProvider: glucoseAndTrendText,
                                                          line2TextProvider: CLKSimpleTextProvider(text: timePlain))
    case .utilitarianSmall, .utilitarianSmallFlat:
        return CLKComplicationTemplateUtilitarianSmallFlat(textProvider: CLKSimpleTextProvider(text: glucoseString))
    case .utilitarianLarge:
        var eventualGlucoseText = ""
        if let eventualGlucose = eventualGlucose,
           let eventualGlucoseString = formatter.string(from: eventualGlucose.doubleValue(for: unit)) {
            eventualGlucoseText = eventualGlucoseString
        }

        return CLKComplicationTemplateUtilitarianLargeFlat(
            textProvider: CLKSimpleTextProvider(
                text: "\(displayText)  \(eventualGlucoseText)"
            )
        )
    case .graphicCorner:
        if #available(watchOSApplicationExtension 5.0, *) {
            return CLKComplicationTemplateGraphicCornerStackText(innerTextProvider: CLKSimpleTextProvider(text: timePlain),
                                                                 outerTextProvider: glucoseAndTrendText)
        } else {
            return nil
        }
    case .graphicCircular:
        if #available(watchOSApplicationExtension 5.0, *) {
            return CLKComplicationTemplateGraphicCircularOpenGaugeSimpleText(
                gaugeProvider: CLKSimpleGaugeProvider(style: .fill, gaugeColor: tintColor, fillFraction: 1),
                bottomTextProvider: CLKSimpleTextProvider(text: trendString),
                centerTextProvider: CLKSimpleTextProvider(text: glucoseString)
            )
        } else {
            return nil
        }
    case .graphicBezel:
        if #available(watchOSApplicationExtension 5.0, *) {
            guard let circularTemplate = templateForFamily(.graphicCircular,
                                                           glucose: glucose,
                                                           unit: unit,
                                                           glucoseDate: glucoseDate,
                                                           trend: trend,
                                                           eventualGlucose: eventualGlucose,
                                                           at: date,
                                                           loopLastRunDate: loopLastRunDate,
                                                           recencyInterval: recencyInterval,
                                                           chartGenerator: makeChart) as? CLKComplicationTemplateGraphicCircular
            else {
                return nil
            }
            return CLKComplicationTemplateGraphicBezelCircularText(circularTemplate: circularTemplate,
                                                                    textProvider: CLKSimpleTextProvider(text: timePlain))
        } else {
            return nil
        }
    case .graphicRectangular:
        if #available(watchOSApplicationExtension 5.0, *) {
            return CLKComplicationTemplateGraphicRectangularLargeImage(
                textProvider: CLKSimpleTextProvider(text: displayText),
                imageProvider: CLKFullColorImageProvider(fullColorImage: makeChart() ?? UIImage())
            )
        } else {
            return nil
        }
    case .graphicExtraLarge:
        if #available(watchOSApplicationExtension 5.0, *) {
            return CLKComplicationTemplateGraphicExtraLargeCircularOpenGaugeSimpleText(
                gaugeProvider: CLKSimpleGaugeProvider(style: .fill, gaugeColor: tintColor, fillFraction: 1),
                bottomTextProvider: CLKSimpleTextProvider(text: trendString),
                centerTextProvider: CLKSimpleTextProvider(text: glucoseString)
            )
        } else {
            return nil
        }
    @unknown default:
        return nil
    }
}
