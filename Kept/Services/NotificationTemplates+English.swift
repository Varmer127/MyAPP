import Foundation

/// The English copy, written for the same moments and tones as the Czech original, not translated word by word.
/// Same rules: the title carries the news, one next step per message, about 80 characters, and the Harsh tone goes
/// after laziness and broken promises, never appearance, health or self-worth.
enum EnglishNotificationCopy: NotificationCopy {
    // MARK: Task escalation, by level. The task's name is the title.

    static let prep = [
        "Starting in 30 minutes. Wrap up what you're doing.",
        "Half an hour to go. Get everything ready so you can just start.",
        "Up in 30 minutes. Your plan, your word.",
        "Half an hour to the start. Close whatever distracts you.",
        "Starting in 30 minutes. Set yourself up for a smooth start.",
        "Half an hour to go. No surprises, it's in your plan.",
    ]

    static let start = [
        "This is the moment. Just start, the rest will follow.",
        "It's {time}, time to start. The first five minutes are the hardest.",
        "Planned for now. Get into it.",
        "Go. Take one small first step, even just opening what you need.",
        "This time is set aside for exactly this. Ready?",
        "It's up now. Forget everything else for a while.",
    ]

    static let direct = [
        "It's {time} and it's still waiting. Start, even for five minutes.",
        "Not done yet. What's the first step? Do just that.",
        "It's {time}. Still open, still doable.",
        "Your word still stands. Get into it now.",
        "Still waiting. Start with a small piece, it'll get going.",
        "It's {time}. Put the phone down and go.",
    ]

    static let strict = [
        "It's {time} and it isn't done. Stop negotiating and start.",
        "Putting it off isn't a plan. Start now, mood or not.",
        "This is your promise. Keep it, even when you don't feel like it.",
        "Every minute you delay is a choice. Choose differently.",
        "Don't wait for motivation. It shows up once you start.",
        "You can write the excuse later. Do it now.",
        "It's {time}. Whatever you're doing can wait. This can't.",
        "Your score and your streak are waiting on this. Finish it.",
        "Missed {n}× lately. Break that today.",
        "Discipline is doing it when you don't want to. Now.",
        "An hour from now you'll be glad you started now.",
        "Stop pushing it back. Five minutes and you're rolling.",
    ]

    static let savage = [
        "Lazy-ass mode again. Open {task} and start.",
        "You keep talking about what you want to achieve. So where's the work?",
        "Take a hard look at your life. This is exactly what keeps you stuck.",
        "You made a commitment and you're running from it again.",
        "You want the results of people who grind, but that's not how you're acting today.",
        "How many more times will you say you'll start later?",
        "Another excuse won't build you a single result.",
        "Nobody's coming to save you. Do the work.",
        "Yesterday you swore it wouldn't happen again. And today?",
        "It's {time}. Still nothing on {task}. That's slacking, not resting.",
        "Your plans are big. Your behaviour today is pathetic.",
        "This is exactly what a day that gets you nowhere looks like. {task} is just lying there.",
        "You can talk. Working, apparently not today.",
        "You've missed {task} {n}× now. That's not bad luck, that's a pattern.",
        "Scrolling or working? You know the answer.",
        "Laziness costs you more than you admit. Start now.",
        "This isn't tiredness. This is avoiding work.",
        "Promises to yourself are the easiest to break. Prove otherwise.",
        "A year from now you'll be exactly where you are if you keep skipping {task}.",
        "The deadline's gone and you've done nothing. Get up and do {task}.",
        "You're not busy. You're procrastinating.",
        "Your word is worth nothing today. Change that.",
        "Stop lying to yourself that you'll do it later. Later doesn't exist.",
        "This is not how a disciplined person acts. {task} is waiting.",
        "While you look for motivation, someone else is already grinding.",
        "Get off your ass. Nobody's going to live your life for you.",
        "You want a better life but won't give up a single hour? Wake up.",
        "Comfort won't get you anywhere. Start now.",
        "Nobody cares about excuses.",
    ]

    static let punchlines = [
        "GET THE FUCK UP.",
        "DO THE FUCKING WORK.",
        "STAY HARD.",
        "NO ONE IS COMING.",
        "EARN YOUR COMFORT.",
        "STOP BEING SOFT.",
        "DISCIPLINE OVER FEELINGS.",
        "PROVE IT. RIGHT NOW.",
        "HUNT OR BE HUNTED.",
        "NO EXCUSES.",
        "YOU SAID YOU WOULD.",
        "KEEP YOUR WORD.",
        "DO IT TIRED.",
        "COMFORT IS A TRAP.",
        "NOBODY CARES. WORK HARDER.",
        "GET UP.",
        "GRIND.",
        "YOU PROMISED.",
    ]

    static let whyStrict = [
        "Your words: “{why}” This is how you get there.",
        "“{why}” That's your reason. Prove it to yourself.",
        "This is what matters to you: “{why}” So go.",
        "Why are you doing this? “{why}” Remember that and start.",
    ]

    static let whySavage = [
        "You said: “{why}” And today you've done nothing for it again.",
        "“{why}” — nice words. Where's the work?",
        "You claimed: “{why}” Your behaviour says the opposite.",
        "“{why}” Do you just want to keep saying it, or actually do it?",
        "If “{why}” really mattered to you, {task} would be done.",
    ]

    // MARK: Sunday planning

    static let sundayOpening = [
        "Sunday is the perfect time to plan. Ten minutes and your week is sorted.",
        "Next week has no plan yet. Let's put it together.",
        "What do you really want to get done next week? Write it down.",
        "A week with a plan holds up better. A few tasks is enough.",
    ]

    static let sundayLater: [NotificationTone: [String]] = [
        .normal: [
            "Next week still has no plan. It takes ten minutes.",
            "Three tasks are enough to give the week a direction.",
            "It's still Sunday. Plan your week so tomorrow you know where you're going.",
            "The plan is waiting. Start with a single task if you like.",
            "A week without a plan is hard to stick to. Let's make one.",
            "Evening's coming and the week's plan still isn't there.",
            "Sunday's ending. Last chance to plan the week in peace.",
            "Last reminder today: plan your week.",
        ],
        .strict: [
            "No plan, nothing to keep. Open Week.",
            "You're putting off planning too. Ten minutes, now.",
            "The week starts tomorrow and you don't know what you'll do in it.",
            "The plan is the week's first promise. Make it.",
            "Still nothing. Plan your week while there's time.",
            "Tomorrow morning there'll be no calm for planning. Now.",
            "Sunday's ending and next week is empty.",
            "Final call. Without a plan you go into the week blind.",
        ],
        .savage: [
            "Can't even be bothered to plan the week? Ten minutes. Now.",
            "You've known all day you have to do it. Still nothing. Plan your week.",
            "You want results and can't even make a plan? Open Week.",
            "This is how every wasted week begins. Plan it.",
            "Slacking on planning too. What about the actual work? Start.",
            "Tomorrow you'll wake up without a plan and wonder why you're behind on everything.",
            "Sunday's almost gone. Your week is a blank page. Your call.",
            "Last reminder. Skip it and you've lost next week before it starts.",
        ],
    ]

    // MARK: Day nudges, morning brief, reality check

    static let dayNudge: [NotificationTone: [String]] = [
        .normal: [
            "Left for today: {n}. Pick one and get into it.",
            "Half the day's behind you. Left: {n}. Which one now?",
            "Evening's coming. Left: {n}. There's still time to finish.",
        ],
        .strict: [
            "Left for today: {n}. Start with the hardest.",
            "Still waiting: {n}. Which will you do within the hour?",
            "The day's ending. Promises not kept: {n}. Finish at least one.",
        ],
        .savage: [
            "Noon. Open commitments: {n}. And you haven't really got going yet.",
            "You promised yourself and it's still lying there. Open: {n}. Stop slacking.",
            "The day's nearly gone. Promises not kept: {n}. Is that what you want to see tonight?",
        ],
    ]

    static let morningGood = [
        "Do it again today.",
        "That's what keeping your word looks like. Again.",
        "Don't let it be a one-off.",
    ]

    static let morningAverage = [
        "So close. Finish it today.",
        "One more task today.",
        "A good base. Add to it today.",
    ]

    static let morningBad = [
        "New day, clean start.",
        "You can't change yesterday. Today you can.",
        "Start with the smallest thing and get rolling.",
    ]

    static let morningNeutral = [
        "Start with the most important thing.",
        "One task at a time. Have a good day.",
        "Today's plan is yours. Go for it.",
    ]

    static let realityCheck: [NotificationTone: [String]] = [
        .normal: [
            "How did today go? It takes a minute.",
            "Time for the evening check. What worked today?",
            "Close the day while there's still time to finish something.",
        ],
        .strict: [
            "The day's ending. Kept or not? Open the check.",
            "Moment of truth. Look at today without excuses.",
            "The evening check is waiting. How many promises hold today?",
        ],
        .savage: [
            "Evening check. Today's promises: {n}. See how many you broke again.",
            "Moment of truth. Did you slack or grind today? Open it.",
            "The day's gone. Numbers don't lie. Open the evening check.",
        ],
    ]

    // MARK: Day streak

    static let streakAtRisk: [NotificationTone: [String]] = [
        .normal: [
            "Your {days} streak ends at midnight. Just finish today.",
            "A few more hours and your {days} streak keeps going. Finish today.",
        ],
        .strict: [
            "Your {days} streak is in danger. It falls at midnight.",
            "{days} in a row. Don't throw it away today; finish it.",
        ],
        .savage: [
            "Your {days} streak dies of laziness today. Get up and finish it.",
            "{days} of work and you'll throw it away for comfort? Finish today.",
        ],
    ]

    static let streakLost: [NotificationTone: [String]] = [
        .normal: [
            "Your {days} streak ended. No worries, a new one starts today.",
            "Your {days} streak broke. One day erases nothing; come back today.",
        ],
        .strict: [
            "Your {days} streak ended. Start again today, first thing.",
            "{days} in a row, and a break yesterday. Don't let it become a habit.",
        ],
        .savage: [
            "Your {days} streak is toast. You blew it off yesterday. Fix it today.",
            "You threw away {days} in a row in a single day. Show today it was a one-off.",
        ],
    ]

    static let streakFollowUp: [NotificationTone: [String]] = [
        .normal: [
            "Days without a streak: {n}. One good day and the flame is back.",
            "Days without a streak: {n}. Start with one small task today.",
            "Days without a streak: {n}. Whenever you come back, Kept is here.",
        ],
        .strict: [
            "Days without a streak: {n}. One slip is a mistake, two is the start of a habit.",
            "Days without a streak: {n}. Stop putting it off and plan today.",
            "Days without a streak: {n}. This is how people quietly give up. Come back.",
        ],
        .savage: [
            "Days without a streak: {n}. The flame is out and you pretend not to see it.",
            "Days without a streak: {n}. You're hiding from your own promises. Open it.",
            "Days without a streak: {n}. This is exactly what giving up looks like. Prove otherwise.",
        ],
    ]

    static let streakFinal: [NotificationTone: String] = [
        .normal: "A week without a streak. I'll stop writing. Kept is here when you're ready.",
        .strict: "A week without a streak. I won't remind you any more. The decision is yours.",
        .savage: "A week without a streak. Reminders clearly don't work, so I'm done. Come back when you mean it.",
    ]

    static let streakRepairHint = "You can still buy back your old streak with points."
    static let streakRepairLastDay = "Today is the last day to buy back your old streak with points."

    static func cue(_ cue: String, starting: Bool) -> String {
        starting ? "It's time. Your plan: \(cue)" : "Starting soon. Your plan: \(cue)"
    }
}
