#!/bin/bash
#####################################################
#	Checkpoint Source Routing Management
# Written By: Brad Gibson
# Date: September 04, 2009
# Features:
#		+ Adds entry to /etc/iproute2/rt_tables
#		+ Copies routes from one routing table to another
#		+ Configures unique default gateway for new table
#		+ Define source routing using "ip rule add"
#		+ Flush route cache (ip route flush cache)
# Running:
#		This script is designed to be added to
#		/etc/rc.d/rc.local to be process on startup.
#
#		Also, after each route addition to the main table
#		this script should be run to synchronize the two
#		route tables.
#
#		
#####################################################

# Define Variables
	TABLE_FROM=main
	TABLE_TO=cogent
	TABLE_TO_PREFIX=202
	DEFGW=38.101.36.65
	DEFINT=eth5
	ROUTE_NETWORKS=(
		'169.156.141.0/24'
		'169.156.60.0/24'
		'169.156.61.0/24'
		'169.156.62.0/24'		
		'169.156.41.16'
		'169.156.41.21'
		'169.156.41.87'
		'169.156.141.53'
		'169.156.32.68'
		'169.156.60.69'
		'169.156.141.78'
		'169.156.41.200'
		)

# Check /etc/iproute2/rt_tables for table entry
	echo ":: Checking '/etc/iproute2/rt_tables' for table '$TABLE_TO'"
	rt_grep=$(grep "$TABLE_TO" /etc/iproute2/rt_tables)
	if [ -z "$rt_grep" ]; then
		echo -e "  =: Adding Table: '$TABLE_TO_PREFIX\t$TABLE_TO'"
		echo -e "$TABLE_TO_PREFIX\t$TABLE_TO" >> /etc/iproute2/rt_tables
		rt_grep=$(grep "$TABLE_TO" /etc/iproute2/rt_tables)
		if [ -z "$rt_grep" ]; then
			echo "  =: Failed!"
		else
			echo "  =: Successful!"
		fi
	else
		echo "  =: Table Found!"
	fi
	echo "  =: Complete!"

# Synchronize routing tables TABLE_FROM -> TABLE_TO
	echo ":: Synchronizing routing tables: '$TABLE_FROM' -> '$TABLE_TO'"
	ip route show table $TABLE_FROM | grep -Ev '^default|^local|^broadcast|^ff|^unreachable|^fe' | while read ROUTE; do
		sync_grep=$(ip route show table $TABLE_TO | grep "$ROUTE")
		if [ -z "$sync_grep" ]; then
			ip route add $ROUTE table $TABLE_TO	# &> /dev/null
			sync_grep=$(ip route show table $TABLE_TO | grep "$ROUTE")
			if [ -z "$sync_grep" ]; then
				echo "  =: Failed to add route: $ROUTE"
			else
				echo "  =: Added route: $ROUTE"
			fi
		else
			echo "  =: Route found: $ROUTE"
		fi
	done
	echo "  =: Complete!"
	
# Check default gateway of TABLE_TO
	echo ":: Checking default gateway of routing table '$TABLE_TO'"
	rtgw_check=$(ip route show table $TABLE_TO | grep "default via $DEFGW dev $DEFINT")
	if [ -z "$rtgw_check" ]; then
		echo "  =: Adding default gateway '$DEFGW/$DEFINT' to table '$TABLE_TO'"
		ip route add default via $DEFGW dev $DEFINT table $TABLE_TO &> /dev/null
		rtgw_check=$(ip route show table $TABLE_TO | grep "default via $DEFGW dev $DEFINT")
		if [ -z "$rtgw_check" ]; then
			echo "  =: Failed!"
		else
			echo "  =: Successful!"
		fi
	else
		echo "  =: Already Exists!"
	fi

# Define Source Routing Rules
	echo ":: Checking rules for source routing"
	success_count=0
	total_count=0
	found_count=0
	failed_count=0
	for net in "${ROUTE_NETWORKS[@]}"; do
		rule_add="from $net lookup $TABLE_TO"
		rule_grep=$(ip rule show | grep "$rule_add")
		if [ -z "$rule_grep" ]; then
			echo "  =: Adding: '$rule_add'"
			ip rule add $rule_add &> /dev/null
			rule_grep=$(ip rule show | grep "$rule_add")
			if [ -z "$rule_grep" ]; then
				((failed_count++))
			else
				((success_count++))
			fi
		else
			echo "  =: Rule Found: '$rule_add'"
			((found_count++))
		fi 
		((total_count++))
	done
	echo "  =: Results: $success_count/$failed_count/$found_count/$total_count (success/fail/found/total)"
	echo "  =: Complete!"

# Flush route cache
	echo ":: Flushing route cache"
	ip route flush cache &> /dev/null
	echo "  =: Complete!"

# Finish
echo ":: Source Routing Configured!"
