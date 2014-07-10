<?
    # Ignore this - PHP only
    ini_set('date.timezone', 'America/New_York');
    include('./psn.php');

    $psn = new psn();

    # Get the user (jid & region) via PSN ID
    $user = $psn->get_jid('emoboy4658');

    # Get an array of games based on the user JID
    $games = $psn->get_games($user['jid']);

    # We need to request trophies on a per-game basis
    foreach($games as $game) {
        $trophies = array();

        # If the data returned is not an array, then it's not valid - skip it
        if(!is_array($game)) {
            continue;
        }

        try {
            # Get an array of the user's trophies for the specified game.
            # These trophies have IDs that are ZERO-INDEXED, meaning, trophy #1 is
            # the 2nd item in the game trophies array.  We do not have access to
            # unique trophy IDs.
            $trophies = $psn->get_trophies($user['jid'], $game['npcommid']);

            # If no trophies are returned, then abort
            if(!$trophies) {
                continue;
            }

            # Get a full list of trophies
            #
            # IMPORTANT:
            # The URL requested by getTrophyList() should only be called AT MOST
            # once per 3 seconds.  Once per 5 seconds is probably a safer bet.
            # It is a 3rd party URL that is rate-limited, so we do not want to abuse it.
            $trophyList = $psn->getTrophyList($game['npcommid']);

            # Let's iterate through the user's trophies and do something with them
            foreach($trophies as $tdata) {
                # Grab the data for the user's trophy from the game's trophy list
                $_t = $trophyList[$tdata['id']];

                # DO SOMETHING WITH THE DATA
                echo " - {$_t['title']} ({$_t['type']})" . PHP_EOL;
            }
        } catch(Exception $e) {
            # noop
        }

        # We can only call $psn->getTrophyList() ONCE PER 3-5 SECONDS due to rate limiting
        sleep(5);
    }
?>