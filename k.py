import pandas
import sqlite3
import re

import sys

from urllib2 import urlopen
import xml.etree.ElementTree as et

#converts minutes string ("32:30") to double (32.5)
def getMinutes(minuteString):

	if (re.search('Did Not Play', minuteString) or minuteString is None or re.search('Suspended', minuteString)):
		return 0

	else:
		split = re.split('[:]', minuteString)
		
		num = int(split[0]) + 0.0
		denom = int(split[1]) + 0.0

		return num + (denom/60)

#returns the odds for games between team1 and team2	
#assumes team1 is home team
def getOdds(team1, team2):

	spread = 0

	feed = urlopen("http://xml.pinnaclesports.com/pinnacleFeed.aspx?sportType=Basketball&sportSubType=NBA")

	tree = et.fromstring(feed.read())
		
	events = tree.find('events')

	#looping through games	
	for event in events:

		participants = event.find('participants')

		#looping through game participants, looking for name matches 
		for participant in participants:

			#if either team is found, assuming we found the game and getting odds
			if (re.match(team1, participant.find('participant_name').text)):

				#getting home team spread

				periods = event.find('periods')

				spread = periods[0].find('spread').find('spread_home').text

	
	return spread	

db = sqlite3.connect("knba")
k = db.cursor()

#FIRST TEAM IS HOME TEAM
teams = (sys.argv[1], sys.argv[2])

print "Team1: ", teams[0]
spread = getOdds(teams[0], teams[1])

print "Calculating scores for", teams[0], "and", teams[1]
print ""

pointsArray = []

for team in teams:

	print team
	if (team == teams[0]):
		otherTeam = teams[1]
	else:
		otherTeam = teams[0]

	totalPoints = 0
	
	#getting roster
	k.execute("SELECT name FROM rosters WHERE team LIKE ?;", (team,))

	players = k.fetchall()

	#calculating average points for each player
	for player in players:	

		#getting points where player's opponent was other team
		k.execute("SELECT points, minutes FROM games_box_simple WHERE playerName LIKE ? AND (homeTeam LIKE ? OR visitorTeam LIKE ?);", (player[0], otherTeam, otherTeam));

		points_tuple = k.fetchall()

		points = []	
		minutes = []

		#converting tuple to list
		for tuple in points_tuple:
			if (tuple[0] is None):
				points.append(0)			
			else:	
				points.append(tuple[0])

			minutes.append(getMinutes(tuple[1]))

	
		#getting points per minute against that team since 2012-2013
		pointSum = 0
		minuteSum = 0

		for point in points:
			pointSum = pointSum + point

		for minute in minutes:
			minuteSum = minuteSum + minute

		if (minuteSum == 0):
			pointsPerMinute = 0
	
		else:
			pointsPerMinute = (pointSum + 0.0) / minuteSum

	
		#averaging minutes of most recent 15 games

		k.execute("SELECT minutes FROM games_box_simple WHERE playerName LIKE ? ORDER BY ROWID DESC", player);

		recentMinutes = 0.0

		i = 0

		while (i < 15):
			minutes_tuple = k.fetchone()
	
			lastGameMinutes = getMinutes(minutes_tuple[0])

			recentMinutes = recentMinutes + lastGameMinutes 

			i = i + 1

		recentMinutes = recentMinutes / 15.0

		totalPoints = (pointsPerMinute * recentMinutes) + totalPoints

		print player[0], " scores ", (pointsPerMinute * recentMinutes), " points"

	print ""
	pointsArray.append(totalPoints)

print ''

print teams[0], " - ", pointsArray[0]

print teams[1], " - ", pointsArray[1]

print "spread: ", spread

print ""

spread = float(spread)

if (pointsArray[0] - spread > pointsArray[1]):
	print "Take the under"

elif (pointsArray[1] - spread < pointsArray[1]):
	print "Take the over"

else:
	print "This shouldn't happen"
			
