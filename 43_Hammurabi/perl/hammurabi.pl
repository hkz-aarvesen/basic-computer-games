#!/usr/bin/env perl
use strict;
use warnings;

# Ongoing work
# Currently at line 270
#
# TODO: Maybe move all the globals into a status object? Same with inputs?

#--------------------------------------#
# Global Variables
#--------------------------------------#
# Original globals
#95 D1=0: P1=0
#100 Z=0: P=95:S=2800: H=3000: E=H-S
#110 Y=3: A=H/Y: I=5: Q=1
#210 D=0

my $year        = 0;                      # Originally Z
my $population  = 95;                     # Originally P
my $stored      = 2800;                   # Originally S
my $harvested   = 3000;                   # Originally H
my $eaten       = $harvested - $stored;   # Originally E
my $yield       = 3;                      # Originally Y
my $acres       = $harvested/$yield;      # Originally A
my $immigrated  = 5;                      # Originally I
my $died        = 0;                      # Originally D
my $total_died  = 0;                      # Originally D1
my $avg_starved = 0;                      # Originally P1

# New globals
my $isPlagued     = 0;
my $consumed    = 0;

# Note we don't need Q, it's used for temporary storage... except that one place for the plague and for how many bushels you're feeding folks.

#--------------------------------------#
# Game Loop
#--------------------------------------#
printHeader();

for ($year = 1; $year <= 10; $year++) {
    printStatus();

    buyOrSellLand();
    feedPeople();
    plantAcres();

    calculate();
    maybeImpeach();
}

printRecap();
gameOver();

#--------------------------------------#
# subroutines
#--------------------------------------#
sub printHeader {
    print <<HEADER;
                               HAMURABI
              CREATIVE COMPUTING  MORRISTOWN, NEW JERSEY

TRY YOUR HAND AT GOVERNING ANCIENT SUMERIA
FOR A TEN-YEAR TERM OF OFFICE.

HEADER

}

sub printStatus{

    my $plague_message = "";
    if ($isPlagued) {
        $plague_message = "A HORRIBLE PLAGUE HAS STRUCK!  HALF THE PEOPLE DIED.\n";
    }

    print <<PROMPT;
HAMURABI:  I BEG TO REPORT TO YOU
IN YEAR $year, $died PEOPLE STARVED, $immigrated CAME TO THE CITY,
${plague_message}POPULATION IS NOW $population.
THE CITY NOW OWNS $acres ACRES.
YOU HARVESTED $yield BUSHELS PER ACRE.
THE RATS ATE $eaten BUSHELS.
YOU NOW HAVE $stored BUSHELS IN STORE.

PROMPT
}

sub _input_int {
    my $in  = <STDIN>;
    my $out = -1;
    chomp $in;
    # does it look like an int or float?
    if ($in =~ /^-?[0-9]+(\.[0-9]+)?/) {
        $out = int($in);
    }
    return $out;
}

sub buyOrSellLand {
    # Note that you cannot both buy and sell land in the same year
    # ca 310

    # TODO: should yield change be in a separate function?
    $yield = int(rand(1) * 10) + 17;

    # Buy land
    while (1) {
        print("LAND IS NOW TRADING AT $yield BUSHELS PER ACRE.\n");
        print("HOW MANY ACRES DO YOU WISH TO BUY? ");

        my $toBuy = _input_int();

        if ($toBuy < 0) {
            gameOverCannotDoThat();
        }
        elsif ($toBuy == 0) {
            # go on to buying
            last;
        }
        else {
            my $cost = $yield * $toBuy;
            if ($cost > $stored) {
                printNotEnoughGrain();
                next;
            }
            $acres  += $toBuy;
            $stored -= $cost;
            return;
        }
    }

    # sell land
    while (1) {
        print("HOW MANY ACRES DO YOU WISH TO SELL? ");
        my $toSell = _input_int();

        if ($toSell < 0) {
            gameOverCannotDoThat();
        }
        elsif ($toSell == 0) {
            # you are done
            last;
        }
        else {
            if ($toSell > $acres) {
                printNotEnoughLand();
                next;
            }
            $acres  -= $toSell;
            $stored += ($yield * $toSell);
            return;
        }
    }
}

sub feedPeople {
    print("\n");

    while (1) {
        print("HOW MANY BUSHELS DO YOU WISH TO FEED YOUR PEOPLE? ");
        my $bushels = _input_int();

        if ($bushels < 0) {
            gameOverCannotDoThat();
        } 
        elsif ($bushels > $stored) {
            printNotEnoughGrain();
            next;
        }
        else {
            # TODO: $fed as a global is bad.
            $consumed = $bushels;
            $stored  -= $consumed;
            last;
        }
    }

}


sub plantAcres{
    print("\n");

    while (1) {
        print("HOW MANY ACRES DO WISH TO PLANT WITH SEED? ");
        my $toPlant= _input_int();

        if ($toPlant< 0) {
            gameOverCannotDoThat();
        } 
        elsif ($toPlant > $acres) {
            printNotEnoughLand();
            next;
        }
        elsif (int($toPlant / 2) > $stored) {
            # 449 REM *** ENOUGH GRAIN FOR SEED?
            printNotEnoughGrain();
            next;
        }
        elsif ( $toPlant > (10 * $population) ) {
            # 454 REM *** ENOUGH PEOPLE TO TEND THE CROPS?
            # one person can tend 10 acres
            print("BUT YOU HAVE ONLY $population PEOPLE TO TEND THE FIELDS!  NOW THEN,\n");
            next;
        }
        else {
            $stored -= int($toPlant / 2);
            last;
        }
    }
}

sub _d6{
    return int(rand(1) * 5) + 1
}
sub calculate{
    # ca 510
    my $chance = _d6();

    # *** A BOUNTIFUL HARVEST!
    $yield = $chance;
    $harvested = $yield * $died;
    $eaten = 0;

    # *** RATS ARE RUNNING WILD!!
    $chance = _d6();
    if ($chance % 2 == 1) {
        $eaten = int($stored / $chance);
        $stored -= ($eaten + $harvested);
    }

    # *** LET'S HAVE SOME BABIES
    $chance = _d6();
    $immigrated = int($chance * ( 20 * $acres + $stored) / $population / 100 + 1);
    $population += $immigrated;

    # *** HOW MANY PEOPLE HAD FULL TUMMIES?
    # note that each person needs to eat 20 bushels per year to e fully fed
    my $fed = int($consumed/20);
    if ($fed >= $population) {
        $died = 0;
    } else {
        $died = $population - $fed;
    }

    # *** HORROS [sic], A 15% CHANCE OF PLAGUE
    # Note that plagues happen after people starve. So you can get some weird numbers here.
    $isPlagued = rand(100) < 15;
    if ($isPlagued) {
        $population = int($population / 2);
    }

}

sub maybeImpeach {
    if ($died > ($population * .45)) {
        print <<IMPEACHED;
YOU STARVED $died PEOPLE IN ONE YEAR!!!
DUE TO THIS EXTREME MISMANAGEMENT YOU HAVE NOT ONLY
BEEN IMPEACHED AND THROWN OUT OF OFFICE BUT YOU HAVE
ALSO BEEN DECLARED NATIONAL FINK!!!!

IMPEACHED
        gameOver();
    }

}

sub printRecap {
    print <<ENDGAME;
IN YOUR 10-YEAR TERM OF OFFICE, $avg_starved PERCENT OF THE
POPULATION STARVED PER YEAR ON THE AVERAGE, I.E. A TOTAL OF
$total_died PEOPLE DIED!!
YOU STARTED WITH 10 ACRES PER PERSON AND ENDED WITH
${ \(int($acres / $population))} ACRES PER PERSON.

ENDGAME

}

sub printNotEnoughGrain {
    print <<COMPLAINT;
HAMURABI:  THINK AGAIN.  YOU HAVE ONLY
$stored BUSHELS OF GRAIN.  NOW THEN,
COMPLAINT
}

sub printNotEnoughLand{
    print("HAMURABI:  THINK AGAIN.  YOU OWN ONLY $acres ACRES.  NOW THEN,\n");
}

sub gameOverCannotDoThat {
    print <<COMPLAINT;

HAMURABI:  I CANNOT DO WHAT YOU WISH.
GET YOURSELF ANOTHER STEWARD!!!!!
COMPLAINT
    gameOver();
}

sub gameOver {
    print("\a" x 10);
    print("SO LONG FOR NOW.\n\n");
    exit;
}
