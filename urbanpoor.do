***************************
**    Country Urbanity   **
**                       **
**     Aaron Chafetz     **
**     USAID/E3/PLC      **
**     Feb 26, 2014      **
***************************

/* Data sources
	- UN
	- Povcal Net
	- Feed the Future
	- USAID/FACTS Info
	- World Bank
*/

clear
set more off

********************************************************************************
********************************************************************************

*******************************************
** MUST RUN THIS SECTION UPON EACH SETUP **
*******************************************

// Set directories & folders //

* Determine path
* change your project path to where you want the project folder to be created
	global projectpath "U:\Chief Economist Work\" //ac
	cd "$projectpath"

* Run a macro to set up study folder
	local pFolder UrbanPoverty
	foreach dir in `pFolder' {
		confirmdir "`dir'"
		if `r(confirmdir)'==170 {
			mkdir "`dir'"
			display in yellow "Project directory named: `dir' created"
			}
		else disp as error "`dir' already exists, not created."
		cd "$projectpath\`dir'"
		}
	* end

* Run initially to set up folder structure
* Choose your folders to set up as the local macro `folders'
	local folders RawData StataOutput StataFigures ExcelOutput Documents
	foreach dir in `folders' {
		confirmdir "`dir'"
		if `r(confirmdir)'==170 {
				mkdir "`dir'"
				disp in yellow "`dir' successfully created."
			}
		else disp as error "`dir' already exists. Skipped to next folder."
	}
	*end

* Set Globals based on path above
	global data "$projectpath\UrbanPoverty\RawData\"
	global output "$projectpath\UrbanPoverty\StataOutput\"
	global graph "$projectpath\UrbanPoverty\StataFigures\"
	global excel "$projectpath\UrbanPoverty\ExcelOutput\"

* install the confirm directory ado if not already installed
	local required_ados fs    
		foreach x of local required_ados { 
			capture findfile `x'.ado
				if _rc==601 {
					cap ssc install `x'
				}
				else disp in yellow "`x' currently installed."
			}
		*end
		
		
********************************************
** Copy data manually into RawData folder **
********************************************


********************************************************************************
********************************************************************************

// COUNTRY INFO //

note: Compiled Feb 19, 2014 ///
	  Sources: ///
		Feed the Future (https://www.feedthefuture.gov/countries) ///
		World Bank/Country and Lending Groups ///
			(http://data.worldbank.org/about/country-and-lending-groups) ///
		USAID/FACTS Info - defined by countries receiving funding in ///
			one or more of these areas: Development Assistance, ///
			Economic Support Fund, Food for Peace Title II, ///
			Global Health Programs - State, Global Health Programs - USAID  

** Import and Combine **
	import excel "$data/countries.xlsx", sheet("usaid") firstrow clear
		save "$output/usaid.dta", replace
	import excel "$data/countries.xlsx", sheet("ftf") firstrow clear
		save "$output/ftf.dta", replace
	import excel "$data/countries.xlsx", sheet("un") firstrow clear
		save "$output/un.dta", replace
	import excel "$data/countries.xlsx", sheet("wb") firstrow clear
		save "$output/wb.dta", replace

*combine
	merge 1:1 wbnum using "$output/usaid.dta", nogen
	merge 1:1 wbnum using "$output/ftf.dta", nogen
	merge 1:1 wbnum using "$output/un.dta", nogen

** Clean **
	lab var country "Country
	lab var wbcode "Word Bank Country Code"
	lab var wbnum "World Bank Country Number"
		note wbnum: for UN countries/regions with no WB Code, 1000 was added ///
			to their index number
	lab var region "Region"
		note region: as defined by the WB Jan 2015 (source: http://data.worldbank.org/about/country-and-lending-groups)
		lab def region 1 "East Asia & Pacific" 2 "Europe & Central Asia" 3 "Latin America & Caribbean" 4 "Middle East & North Africa" 5 "South Asia" 6 "Sub-Saharan Africa"
		lab val region region 
	rename class inclvl
		lab var inclvl "Country Income Level"
		note inclvl: as defined by the WB Jan 2015 (source: http://data.worldbank.org/about/country-and-lending-groups)
		lab def inclvl 1 "Low income" 2 "Lower middle income" 3 "Upper middle income" 4 "High income"
		lab val inclvl inclvl
	lab var usaid "USAID Country"
		note usaid: as defined by any country receiving funding from USAID in ///
			one or more of these areas: Development Assistance, Economic Support Fund ///
			Food for Peace Title II, Global Health Programs - State, Global Health ///
			Programs - USAID	(source: FACTS Info, Feb 2015)
		replace usaid=0 if usaid==.
	lab var ftf "Feed the Future Country"	
		replace ftf=0 if ftf==.
		note ftf: as of Feb 2015 (source: https://www.feedthefuture.gov/countries)
		
	lab def yn 0 "No" 1 "Yes"
	lab val ftf usaid yn

	drop regiontxt classtxt country_nospace

	order index country wbcode wbnum region inclvl usaid ftf

	save "$output/countries.dta", replace


********************************************************************************
********************************************************************************

// POVCAL DATA //

note: Proportion of population below $1.25 (PPP)) per day
note: Source: Povcal Net

** Import **

*Urban poverty below natl poverty line
	import excel "$data/Urban population below national poverty line.xls", sheet("povcaledit") firstrow clear
		gen type = 8
		save "$output/urban pov.dta", replace
*Rural poverty below natl poverty line
	import excel "$data/Rural population below national poverty line.xls", sheet("povcaledit") firstrow clear
		gen type = 9
		save "$output/ruralpov.dta", replace
*Total poverty below natl poverty line
	import excel "$data/Total population below national poverty line.xls", sheet("povcaledit") firstrow clear
		gen type = 10
		save "$output/totalpov.dta", replace
*combine
	use "$output/urban pov.dta", replace
	append using "$output/ruralpov.dta"
	append using "$output/totalpov.dta"

** Clean **
	ds, has(varl *Footnote* *Nature*)
	drop `r(varlist)' Id
	rename Country country

*rename year variables
	foreach year of var E H K N Q T W Z AC AF AI AL AO AR AU AX BA BD BG BJ BM BP BS BV{
		local l`year' : variable label `year'
		rename `year' y`l`year''
	}
	*end

	lab var country "Country"
	lab var wbcode "Word Bank Country Code"
	lab var wbnum "World Bank Country Number"
	lab var type "Dataset"
		lab def type 1 "Urban proportion" 2 "Urban Population" 3 "Rural Population" ///
			4 "Total Population" 5 "Urban Growth Rate" 6 "Rural Growth Rate" ///
			7 "Total Growth Rate" 8 "Urban Poverty" 9 "Rural Poverty" 10 "Total Poverty"
		lab val type type

	save "$output/povcal.dta", replace

********************************************************************************
********************************************************************************

// UN DATA //

** Import & Combine **
	note: source: UN Population Division, June 2014
	note: Population at Mid-Year by Major Area, Region and Country, ///
		  1950-2050 (thousands)
	
*proportion urban
	import excel "$data/WUP2014-F02-Proportion_Urban.xls", sheet("DATA") cellrange(A17:Y290) firstrow clear
	gen type = 1
	save "$output/urbanproportion.dta", replace
*urban population
	import excel "$data/WUP2014-F03-Urban_Population.xls", sheet("DATA") cellrange(A17:Y290) firstrow clear
	gen type = 2
	save "$output/urbanpop.dta", replace	
*rural population
	import excel "$data/WUP2014-F04-Rural_Population", sheet("DATA") cellrange(A17:Y290) firstrow clear
	gen type = 3
	save "$output/ruralpop.dta", replace
*total population
	import excel "$data/WUP2014-F05-Total_Population", sheet("DATA") cellrange(A17:Y290) firstrow clear
	gen type = 4
	save "$output/totalpop.dta", replace
*urban growth rate
	import excel "$data/WUP2014-F06-Urban_Growth_Rate", sheet("DATA") cellrange(A17:X290) firstrow clear
	gen type = 5
	save "$output/urbangrowth.dta", replace
*rural growth rate
	import excel "$data/WUP2014-F07-Rural_Growth_Rate", sheet("DATA") cellrange(A17:X290) firstrow clear
	gen type = 6
	save "$output/ruralgrowth.dta", replace
*total growth rate
	import excel "$data/WUP2014-F08-Total_Growth_Rate", sheet("DATA") cellrange(A17:X290) firstrow clear
	gen type = 7
	save "$output/totalgrowth.dta", replace
	
*combine UN growth stats
	note: Average Annual Rate of Change of the Urban Population, 1950-2050 (per cent)
	use "$output/urbangrowth.dta", clear
	append using "$output/ruralgrowth.dta"
	append using "$output/totalgrowth.dta"
	
	*rename year variables
	local i = 1955
	foreach year of var E F G H I J K L M N O P Q R S T U V W X {
		rename `year' y`i'
		lab var y`i' "Avg Annual Rate of Population Change over past 5 years"
		local i = `i' + 5
		}
		*end
	save "$output/growthcombined.dta", replace

*combine UN stats
	use "$output/urbanproportion.dta", clear
	append using "$output/urbanpop.dta"
	append using "$output/ruralpop.dta"
	append using "$output/totalpop.dta"

	*rename year variables
	foreach year of var E F G H I J K L M N O P Q R S T U V W X Y{
		local l`year' : variable label `year'
		rename `year' y`l`year''
		}
		*end
		
	append using "$output/growthcombined.dta"
	
** Clean dataset	**
	rename Major country
	rename Index index
		
	lab var type "Dataset"
	lab def type 1 "Urban proportion" 2 "Urban Population" 3 "Rural Population" ///
		4 "Total Population" 5 "Urban Growth Rate" 6 "Rural Growth Rate" ///
		7 "Total Growth Rate" ///
		8 "Urban Poverty (Avg Annual Rate of Population Change over past 5 years)" ///
		9 "Rural Poverty (Avg Annual Rate of Population Change over past 5 years)" ///
		10 "Total Poverty (Avg Annual Rate of Population Change over past 5 years)"
	lab val type type

	drop Note CountryCode

*bring in wbnum for merging datasets & reorder variables
	merge m:1 index using "$output/un.dta", nogen keepusing(wbcode wbnum)
	order index country wbcode wbnum
	
	save "$output/uncombine.dta", replace

********************************************************************************
********************************************************************************

// MERGE DATASETS //

	use "$output/uncombine.dta", clear
	append using "$output/povcal.dta"
	merge m:1 wbnum using "$output/countries.dta", nogen

	drop index
	replace wbcode="." if wbcode==""

*reorder
	order country wbcode wbnum region inclvl usaid ftf type ///
		y1950 y1955 y1960 y1965 y1970 y1975 y1980 y1985 y1990 y1991 y1992 y1993 ///
		y1994 y1995 y1996 y1997 y1998 y1999 y2000 y2001 y2002 y2003 y2004 y2005 /// 
		y2006 y2007 y2008 y2009 y2010 y2011 y2012 y2013
	sort type wbnum

*label variables
	lab var country "Country"
	lab var wbcode "Word Bank Country Code"
	lab var wbnum "World Bank Country Number"
		note wbnum: for UN countries/regions with no WB Code, 1000 was added to their index number
		
/* for figures, want three country categories 
	(1) FtF, (2) USAID, non-FtF, (3) Other developing (non-USAID and non-FtF) */
	gen group = 1 if ftf==1
		replace group = 2 if usaid==1 & ftf==0
		replace group = 3 if inclvl!=4 & inclvl!=. & usaid==0 & ftf==0
		lab def group 1 "Feed the Future" 2 "USAID (non-FtF)" ///
			3 "Other developing countries"
		lab val group group
		lab var group "Country Group (2014)"
*drop non-developing countries
	tab country if group==. //list all non-developing countries dropping
	drop if group==. // only developing countries remain in dataset

*clear out intermediary .dta files
	cd "$projectpath\UrbanPoverty\StataOutput\"
	fs *
	foreach f in `r(files)'{
		di "removing `f'"
		erase "`f'"
		}
		*end
*save
	cd "$projectpath"
	save "$output/urbanpov.dta", replace

********************************************************************************
********************************************************************************

// Figures //


** Urban poverty over time **

use "$output/urbanpov.dta", clear


*just looking at urban proportion of population below $1.25 (PPP)) per day
	keep if type==8
	drop type
* remove years not in povcal dataset
	drop y1950-y1985 y2015-y2050

*look at # of observations each year
	codebook y1990-y2013, c

*reshape to long to have 1 urban poverty variable & 1 year variable
	reshape long y, i(wbnum) j(year)
		rename y urbpoor
		lab var urbpoor "Proportion of population below $1.25 (PPP) per day)"
		lab var year "Year"
		order wbnum country wbcode year
		
* to have same # of obs per year, interpolate to fill gaps by country
	by wbnum: ipolate urbpoor year, gen(iurbpoor) // interpolate
	by wbnum: ipolate urbpoor year, gen(eurbpoor) epolate //extrapolate
		lab var iurbpoor "Interpolated Proportion of population below $1.25 (PPP) per day)"
		lab var eurbpoor "Extrapolated Proportion of population below $1.25 (PPP) per day)"
		format %9.1f iurbpoor eurbpoor
	* # of obs by urban poverty stat 
	tabstat urbpoor iurbpoor eurbpoor, by(year) s(count)
		
* graph individual country levels by category
	levelsof group, local(levels)	
		foreach g of local levels{
		di "...Generating graphs for `: label (group) `g''"
		graph twoway (connect eurbpoor year, lcolor(gs5) mcolor(gs5) mfcolor(white)) ///
			(scatter urbpoor year, mcolor(gs5) mfcolor(cranberry) ///
			ytitle("Percent (%)") ///
			yline(100) ylabel(,format(%9.0g)) ///
			legend(order(2 "Recorded Data" 1 "Extrapolated")size(small))) ///
			if group==`g', by(country, ///
			title("Percent of Urban Population Below $1.25 (PPP) Per Day") ///
			sub("`: label (group) `g''") ///
			note("Source: Povcal Net"))
		graph export "$graph/urbanpoor_cat`g'.pdf", replace
		}
		*end

* create average for developing countries each year
	egen yrly_avg = mean(eurbpoor), by(year) 
		lab var yrly_avg "Avg % urban poor by group & year"
		
* create average for each country & year
	egen group_yrly_avg = mean(eurbpoor), by(year group) 
		lab var group_yrly_avg "Avg % urban poor by group & year"
		
*graph % urban poor over time
	sort year group wbnum
	graph twoway (connect group_yrly_avg year if group==1, msymbol(O)) ///
		(connect group_yrly_avg year if group==2, msymbol(T)) ///
		(connect yrly_avg year, msymbol(D)), ///
		legend(size(small) rows(1)) ///
		title("Percent of Urban Population Below $1.25 (PPP) Per Day") ///
		sub("1990-2013") ///
		note("Sources: Povcal Net, World Bank/WDI, & USAID") ///
		ytitle("Percent") ///
		legend(order (1 "Feed the Future" 2 "USAID (non-FtF)" 3 "All developing") ///
		size(small) rows(1))
	graph export "$graph/urbanpoor.pdf", replace	
	
* look for outliers for certain groups and years based on graph
	/*	-1994, Other
		-2005, USAID
		-2007, FtF
		-2008, Other
		-2009, Other	*/
	levelsof group, local(levels)	
	foreach g of local levels{
		di "-> group = `: label (group) `g''"
		*di "-> group = ‘: label (group) ‘g’’"
		tabstat eurbpoor if group==`g', by(year) s(n mean sd min max) 
		}
		*end	
	list country eurbpoor if year==1994 & group==3
	list country eurbpoor if year==2005 & group==2
	list country eurbpoor if year==2007 & group==1
	list country eurbpoor if year==2008 & group==3
	list country eurbpoor if year==2009 & group==9

* reshape and pull country level data by year for comparison in Excel
	drop yrly_avg group_yrly_avg
	reshape wide urbpoor iurbpoor eurbpoor, i(wbnum) j(year)
	*browse group country urbpoor* //original data
	export excel group country urbpoor* ///
		using "$excel/extrapolated_urbanpov_comparison.xlsx", ///
		sheet("original") sheetreplace firstrow(variables)
	*browse group country eurbpoor* //extrapolated data
	export excel group country eurbpoor* ///
		using "$excel/extrapolated_urbanpov_comparison.xlsx", ///
		sheet("extrapolated") sheetreplace firstrow(variables)
	

	
** Urban Percent **

use "$output/urbanpov.dta", clear

*just looking at urban proportion
	keep if type==1
	drop type
* remove years not in dataset
	drop y1991-y1994 y1996-y1999 y2001-y2004 y2006-y2009 y2011-y2013

*look at # of observations each year
	codebook y*, c

*reshape to long to have 1 urban poverty variable & 1 year variable
	reshape long y, i(wbnum) j(year)
		rename y urbpop
		lab var urbpop "Proportion of population urban"
		lab var year "Year"
		order wbnum country wbcode year

* create average for developing countries each year
	egen yrly_avg = mean(urbpop), by(year) 
		lab var yrly_avg "Avg % urban poor by year"
		
* create average for each country & year
	egen group_yrly_avg = mean(urbpop), by(year group) 
		lab var group_yrly_avg "Avg % urban poor by group & year"
	
*graph % urban pop over time
	sort year group wbnum
	graph twoway connect group_yrly_avg year if group==1, msymbol(O) || ///
		connect group_yrly_avg year if group==2, msymbol(T) || ///
		connect yrly_avg year, msymbol(D) ///
		legend(size(small) rows(1)) ///
		title("Mean Urban Population Percentage") ///
		sub("1950-2050") ///
		note("Sources: UN, World Bank/WDI, & USAID") ///
		legend(order (1 "Feed the Future" 2 "USAID (non-FtF)" 3 "All developing") ///
		size(small) rows(1)) ///
		ytitle("Percent") ///
		yline(50, lpattern(dash) lcolor(gs12)) /// 
		xlabel(1950(25)2050) ///
		xline(2015, lcolor(gs14))
	graph export "$graph/urbanpop.pdf", replace	
 


** Urban Percent by Region **

use "$output/urbanpov.dta", clear

*just looking at urban proportion
	keep if type==1
	drop type
* remove years not in dataset
	drop y1991-y1994 y1996-y1999 y2001-y2004 y2006-y2009 y2011-y2013

*look at # of observations each year
	codebook y*, c

*reshape to long to have 1 urban poverty variable & 1 year variable
	reshape long y, i(wbnum) j(year)
		rename y urbpop
		lab var urbpop "Proportion of population urban"
		lab var year "Year"
		order wbnum country wbcode year

* create average for each year
	egen region_yrly_avg = mean(urbpop), by(region group) 
		lab var region_yrly_avg "Avg % urban poor by region & group & year"
		
* create average for each region  country & year
	egen region_group_yrly_avg = mean(urbpop), by(year region group) 
		lab var region_group_yrly_avg "Avg % urban poor by region & group & year"

* graph combined region plot	
	sort year region group
	twoway (scatter region_group_yrly_avg year if group==1, ///
		msymbol(smcircle) connect(l)) ///
		(scatter region_group_yrly_avg year if group==2, ///
		msymbol(smtriangle)connect(l)) ///
		(scatter region_group_yrly_avg year if group==3, ///
		msymbol(smdiamond) connect(l)), ///
		by(region, ///
		title("Mean Urban Population Percentage") ///
		note("Sources: UN, World Bank/WDI, & USAID")) 	///
		legend(order (1 "Feed the Future" 2 "USAID (non-FtF)" 3 "Other developing") ///
		size(small) rows(1)) ///
		ytitle("Percent") ///
		ylabel(0(20)80, labsize(small)) ///
		yline(50, lpattern(dash) lcolor(gs12)) /// 
		xlabel(1950(25)2050, labsize(vsmall)) ///
		xline(2015, lcolor(gs14))
	graph export "$graph/urbanpop_reg_comb.pdf", replace	
	
* individual graphs for each region
	sort year region group
	levelsof region, local(levels)	
	foreach r of local levels{	
		if `r'==4{
			graph twoway connect region_group_yrly_avg year if region==`r' & group==2, msymbol(T) || ///
				connect region_group_yrly_avg year if region==`r' & group==3, msymbol(D) ///
				legend(size(small) rows(1)) ///
				title("Mean Urban Population Percentage") ///
				sub("`: label (region) `r''") ///
				legend(order (1 "USAID (non-FtF)" 3 "Other developing") ///
				size(small) rows(1)) ///
				note("Sources: UN, World Bank/WDI, & USAID") ///
				ytitle("Percent") ///
				ylabel(0(20)80) ///
				yline(50, lpattern(dash) lcolor(gs12)) /// 
				xlabel(1950(25)2050) ///
				xline(2015, lcolor(gs14))
			}
		else{
			graph twoway connect region_group_yrly_avg year if region==`r' & group==1, msymbol(O) || ///
				connect region_group_yrly_avg year if region==`r' & group==2, msymbol(T) || ///
				connect region_group_yrly_avg year if region==`r' & group==3, msymbol(D) ///
				legend(size(small) rows(1)) ///
				title("Mean Urban Population Percentage") ///
				sub("`: label (region) `r''") ///
				legend(order (1 "Feed the Future" 2 "USAID (non-FtF)" 3 "Other developing") ///
				size(small) rows(1)) ///
				note("Sources: UN, World Bank/WDI, & USAID") ///
				ytitle("Percent") ///
				ylabel(0(20)80) ///
				yline(50, lpattern(dash) lcolor(gs12)) /// 
				xlabel(1950(25)2050) ///
				xline(2015, lcolor(gs14))
			}
		graph export "$graph/urbanpop_reg`r'.pdf", replace	
		}
		*end
		


** Urban to Rural Ratio **

use "$output/urbanpov.dta", clear

*start with rural (to merge into urban
	tab type
	keep if type==3 //Rural Population
	drop type

* remove years not in dataset
	drop y1991-y1994 y1996-y1999 y2001-y2004 y2006-y2009 y2011-y2013

*look at # of observations each year
	codebook y*, c
	
*drop unnecessary variables
	drop country wbcode region inclvl usaid ftf
	
*reshape to long to have 1 urban poverty variable & 1 year variable
	reshape long y, i(wbnum) j(year)
		rename y ruralpop
		lab var ruralpop "Rural Population"
		lab var year "Year"
		
*save for merging
	save "$output/ruralpop_long", replace
	
*reopen main file		
	use "$output/urbanpov.dta", clear

*need urban pop (to merge into urban
	tab type
	keep if type==2 //Urban Population
	drop type

* remove years not in dataset
	drop y1991-y1994 y1996-y1999 y2001-y2004 y2006-y2009 y2011-y2013

*look at # of observations each year
	codebook y*, c
	
	*reshape to long to have 1 urban poverty variable & 1 year variable
	reshape long y, i(wbnum) j(year)
		rename y urbpop
		lab var urbpop "Urban Population"
		lab var year "Year"

*merge with rural population
	merge 1:1 wbnum year using "$output/ruralpop_long", nogen

*generate ratio
	gen urbruralratio = urbpop/ruralpop
		lab var urbruralratio "Ratio of Urban to Rural Population"

* create average for each year
	egen yrly_avg = mean(urbruralratio), by(year) 
		lab var yrly_avg "Avg urban/rural ratio by year"
	
* create average for each country & year
	egen group_yrly_avg = mean(urbruralratio), by(year group) 
		lab var group_yrly_avg "Avg urban/rural ratio by group & year"
	
		
*graph urban/rural ratio over time
	sort year group wbnum  
	graph twoway connect group_yrly_avg year if group==1, msymbol(O) || ///
		connect group_yrly_avg year if group==2, msymbol(T) || ///
		connect yrly_avg year, msymbol(D) ///
		legend(size(small) rows(1)) ///
		title("Mean Urban to Rural Population Ratio") ///
		sub("1950-2050") ///
		note("Sources: UN, World Bank/WDI, & USAID") ///
		legend(order (1 "Feed the Future" 2 "USAID (non-FtF)" 3 "All developing") ///
		size(small) rows(1)) ///
		ytitle("Urban/Rural Ratio") ///
		yline(1, lpattern(dash) lcolor(gs12)) ///
		xlabel(1950(25)2050) ///
		xline(2015, lcolor(gs14))
	graph export "$graph/urbruralratio.pdf", replace	
 

*graph individual countries by category for urban/rural ratio
	sort year group wbnum  
	levelsof group, local(levels)	
		foreach g of local levels{
		graph twoway connected urbruralratio year if group==`g', by(country, ///
			title("Urban to Rural Population Ratio") ///
			sub("`: label (group) `g''") ///
			note("")) ///
			ytitle("Urban/Rural Ratio") ///
			yline(1, lpattern(dash) lcolor(gs12)) ///
			xlabel(1950(25)2050) ///
			xline(2015, lcolor(gs14))
		graph export "$graph/urbruralratio_cat`g'.pdf", replace
		di "`: label (group) `g'' graph generated & saved"
		}
		*end
