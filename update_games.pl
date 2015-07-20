use warnings;
use strict;
use autodie;

use HTML::Tree;
use HTML::TreeBuilder;
use HTML::TableExtract;

use DateTime;
use Data::Dumper;

use DBI;

my $db = DBI->connect("dbi:SQLite:dbname=knba", "", "");

#reading datetime from file
open(my $timeFH, ".time") or die "$!\n";
my $timeStr = <$timeFH>;
close ($timeFH);

my ($day, $month, $year) = split(/ /, $timeStr);

print "Starting at day $day month $month year $year\n";

my $start = DateTime->new(
	day => $day,
	month => $month,
	year => $year );

my $stop = DateTime->today();

print "$stop\n";

#looping through days, finding box scores
while ($start->add(days => 1) <= $stop) {

	if ($start->month() > 6 and $start->month() < 10) {
		next;
	}

	print "adding a day \n";

	#eliminating box scores from earlier that day - if the program was interrupted prior to the day's work
	my $dayString = join("", $start->year(), $start->month(), $start->day(), "0");

	#deleting from both tables
	my $deleteSt = $db->prepare("DELETE FROM games_box_simple WHERE gameID LIKE ?;");
	$deleteSt->execute('%' . $dayString . '%') or die $DBI::errstr;
	$deleteSt = $db->prepare("DELETE FROM games_box_advanced WHERE gameID LIKE ?;");
	$deleteSt->execute('%' . $dayString . '%') or die $DBI::errstr;


	#getting box scores for that day
	my $dayURL = join("", "http://www.basketball-reference.com/boxscores/index.cgi?month=" . $start->month() . "&day=" . $start->day() . "&year=" . $start->year());

	print "$dayURL \n";
	system("curl '$dayURL' > .boxscore");

	my $tree = HTML::TreeBuilder->new_from_file(".boxscore");
	$tree->parse_file;

	my $boxURL;
	my $td;

	my @tds = $tree->look_down('class' => "align_right bold_text");

	foreach my $td (@tds) {

		#getting each box score	
		$boxURL = "http://www.basketball-reference.com" . $td->look_down("_tag" => "a")->attr("href");

		add_score($boxURL);

	}	

	print "ADDING DAY\n";
	#writing to file
	my $fh;

	open ($fh, ">.time") or die "$!\n";
	print $fh $start->day(), " ", $start->month(), " ", $start->year();
	print "TIME: ", $start->day(), " ", $start->month(), " ", $start->year(), "\n";
	close ($fh);

	sleep 2;

}

#adds game box scores to db			
sub add_score {
	print "Adding score for url $_[0]\n";
	#getting gameID
	my $url = $_[0];
	my ($discard, $gameID) = split(/\/boxscores\//, $url);
	$gameID =~ s/\.html//;

	system("curl '$url' > .boxscore");

	my $tree = HTML::TreeBuilder->new_from_file(".boxscore");
	$tree->parse_file;

	my $titleString = $tree->look_down('_tag' => "title")->as_text;

	#gets teams from title
	my @teams = @{ getTeams($titleString) };

	my @tables = $tree->look_down('class' => "sortable  stats_table");

	#four different tables
	my $i = 0;
	foreach (@tables) {
		my $table = $_->as_HTML;
		print "Parsing table...\n";
		my $te = HTML::TableExtract->new() or die "Can't create: $!\n";
		$te->parse($table) or die "Can't parse table : $!\n";
		my @rows = $te->rows;

		my $basicInsert = $db->prepare("INSERT INTO games_box_simple VALUES(?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?);");
		my $advancedInsert = $db->prepare("INSERT INTO games_box_advanced VALUES(?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?);");

		foreach my $row (@rows) {

			my @row = @{ $row };
	
			if ($row[0] =~ /^$/ or $row[0] =~ /Starters/ or $row[0] =~ /Reserves/ or $row[0] =~ /Team Totals/ig) {
				next;
			}

			if ($i == 0) { #first team, basic box score
				my $teamName = $teams[0];
				$basicInsert->execute($teams[0], $teams[1], $gameID, $row[0], $teamName, $row[1], $row[2], $row[3], $row[4], $row[5], $row[6], $row[7], $row[8], $row[9], $row[10], $row[11], $row[12], $row[13], $row[14], $row[15], $row[16], $row[17], $row[18], $row[19], $row[20]) or die $DBI::errstr;
			}

			if ($i == 1) { #first team, advanced box score
				my $teamName = $teams[0];
				$advancedInsert->execute($teams[0], $teams[1], $gameID, $row[0], $teamName, $row[1], $row[2], $row[3], $row[4], $row[5], $row[6], $row[7], $row[8], $row[9], $row[10], $row[11], $row[12],     $row[13], $row[14], $row[15]) or die $DBI::errstr;
			}

			if ($i == 2) { #second team, basic box score
				my $teamName = $teams[1];
				$basicInsert->execute($teams[0], $teams[1], $gameID, $row[0], $teamName, $row[1], $row[2], $row[3], $row[4], $row[5], $row[6], $row[7], $row[8], $row[9], $row[10], $row[11], $row[12], $row[13], $row[14], $row[15], $row[16], $row[17], $row[18], $row[19], $row[20]) or die $DBI::errstr;
			
			}
			if ($i == 3) { #second team, advanced box score
				my $teamName = $teams[1];
				$advancedInsert->execute($teams[0], $teams[1], $gameID, $row[0], $teamName, $row[1], $row[2], $row[3], $row[4], $row[5], $row[6], $row[7], $row[8], $row[9], $row[10], $row[11], $row[12], $row[13], $row[14], $row[15]) or die $DBI::errstr;
			}
		}
		$i++;
		print "Parsing table $i \n\n";
	}
	sleep 2;
}

sub getTeams {
	print "running getTeams\n";
	my $title = $_[0];
	my ($at, $other) = split(/ Box Score/, $title);
	my @teams = split(/ at /, $at);
	return \@teams;
}	
