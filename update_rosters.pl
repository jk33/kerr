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

my @teamNames = ("Atlanta Hawks", "Boston Celtics", "Brooklyn Nets", "Charlotte Hornets", "Chicago Bulls", "Cleveland Cavaliers", "Dallas Mavericks", "Denver Nuggets", "Detroit Pistons", "Golden State Warriors", "Houston Rockets", "Indiana Pacers", "Los Angeles Clippers", "Los Angeles Lakers", "Memphis Grizzlies", "Miami Heat", "Milwaukee Bucks", "Minnesota Timberwolves", "New Orleans Pelicans", "New York Knicks", "Oklahoma City Thunder", "Orlando Magic", "Philadelphia 76ers", "Phoenix Suns", "Portland Trail Blazers", "Sacramento Kings", "San Antonio Spurs", "Toronto Raptors", "Utah Jazz", "Washington Wizards");

my @teams = qw/ATL BOS BRK CHO CHI CLE DAL DEN DET GSW HOU IND LAC LAL MEM MIA MIL MIN NOP NYK OKC ORL PHI PHO POR SAC SAS TOR UTA WAS/;

my $i = 0;

foreach (@teams) {
	
	print "Parsing team $teams[$i]\n";
	my $rosterURL = join("", "http://www.basketball-reference.com/teams/", $teams[$i], "/2015.html");

	system("curl '$rosterURL' > .roster");

	my $tree = HTML::TreeBuilder->new_from_file(".roster");
	$tree->parse_file;

	my $rosterTable = $tree->look_down("id" => "roster")->as_HTML;

	my $te = HTML::TableExtract->new() or die "Can't create table: $!\n";
	
	$te->parse($rosterTable);

	my @rows = $te->rows;

	foreach (@rows) {

		my @cells = @{ $_ };

		if ($cells[0] =~ /\d+/g) {
			my $st = $db->prepare("INSERT INTO rosters VALUES(?, ?, ?, ?, ?, ?, ?,?, ?);");
			$st->execute($teamNames[$i], $cells[0], $cells[1], $cells[2], $cells[3], $cells[4], $cells[5], $cells[7], $cells[8]) or die $DBI::errstr;

		}
	}

	$i++;

	sleep 2;
}
