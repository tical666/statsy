Model = {
    char = {
        lastBattlefieldStatus = {},
        stats = {
            [BATTLEFIELD_NONE] = {
                games = {report = true},
                wins = {report = true},
                losses = {report = true},
                winRate = {report = true},
                commonStats = {
                    killingBlows = {report = false},
                    deaths = {report = false},
                    honorableKills = {report = false}
                },
                maxStats = {
                    killingBlows = {report = false},
                    deaths = {report = false},
                    honorableKills = {report = false}
                }
            },
            [BATTLEFIELD_WARSONG] = {
                games = {report = false},
                wins = {value = 0, report = false},
                losses = {value = 0, report = false},
                winRate = {report = false},
                commonStats = {
                    killingBlows = {value = 0, report = false},
                    deaths = {value = 0, report = false},
                    honorableKills = {value = 0, report = false},
                    flagCaptures = {value = 0, report = false},
                    flagReturns = {value = 0, report = false}
                },
                maxStats = {
                    killingBlows = {value = 0, report = false},
                    deaths = {value = 0, report = false},
                    honorableKills = {value = 0, report = false},
                    flagCaptures = {value = 0, report = false},
                    flagReturns = {value = 0, report = false}
                }
            },
            [BATTLEFIELD_ARATHI] = {
                games = {report = false},
                wins = {value = 0, report = false},
                losses = {value = 0, report = false},
                winRate = {report = false},
                commonStats = {
                    killingBlows = {value = 0, report = false},
                    deaths = {value = 0, report = false},
                    honorableKills = {value = 0, report = false},
                    basesAssaulted = {value = 0, report = false},
                    basesDefended = {value = 0, report = false}
                },
                maxStats = {
                    killingBlows = {value = 0, report = false},
                    deaths = {value = 0, report = false},
                    honorableKills = {value = 0, report = false},
                    basesAssaulted = {value = 0, report = false},
                    basesDefended = {value = 0, report = false}
                }
            },
            [BATTLEFIELD_ALTERAC] = {
                games = {report = false},
                wins = {value = 0, report = false},
                losses = {value = 0, report = false},
                winRate = {report = false},
                commonStats = {
                    killingBlows = {value = 0, report = false},
                    deaths = {value = 0, report = false},
                    honorableKills = {value = 0, report = false},
                    graveyardsAssaulted = {value = 0, report = false},
                    graveyardsDefended = {value = 0, report = false},
                    towersAssaulted = {value = 0, report = false},
                    towersDefended = {value = 0, report = false},
                    minesCaptured = {value = 0, report = false},
                    leadersKilled = {value = 0, report = false},
                    secondaryObjectives = {value = 0, report = false}
                },
                maxStats = {
                    killingBlows = {value = 0, report = false},
                    deaths = {value = 0, report = false},
                    honorableKills = {value = 0, report = false},
                    graveyardsAssaulted = {value = 0, report = false},
                    graveyardsDefended = {value = 0, report = false},
                    towersAssaulted = {value = 0, report = false},
                    towersDefended = {value = 0, report = false},
                    minesCaptured = {value = 0, report = false},
                    leadersKilled = {value = 0, report = false},
                    secondaryObjectives = {value = 0, report = false}
                }
            }
        }
    },
    profile = {
        makeConfirmScreenshots = false, -- Делать скриншот игры при вызове на БГ (для отлавливания события вне игры)
        sendConfirmWhisper = true, -- Отправлять сообщение о старте игры себе для мигания иконки игры
        showBattlefieldLevels = true,   -- Показывать уровни игроков на БГ
        showBattlefieldClassColors = true,  -- Окрашивать имена игроков согласно классам на БГ
        minimap = {
            shown = true,
            locked = false,
            minimapPos = 218
        }
    }
}