***************************
**     Urban Poverty     **
**       Addendum        **
**     Aaron Chafetz     **
**     USAID/E3/PLC      **
**     Mar 25, 2014      **
**	  updated 5.26.14    **
***************************

/* Data sources
	- UN
	- USAID
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

// COUNTRY DATA //

use "$output/urbanpov.dta", clear

*gen unique id for reshaping
	gen id  = _n
*reshape to have one country & year row
	reshape long y, i(id) j(year)
	drop id
	rename y data
*create another unique indentifier for second reshape
	egen id = group(country year)
	drop if type==. //Kosovo
*need to remove extra variables for second reshape (will merge back
	preserve
		keep country ftf usaid inclvl region wbnum wbcode group 
		*keep only one observation per country
		by country, sort: gen num = _n
		keep if num==1
		drop num
		save "$output/temp_merge.dta", replace
	restore
	drop ftf usaid inclvl region wbnum wbcode group
*second reshape
	reshape wide data, i(id) j(type)
*merge country information back on
	merge m:1 country using "$output/temp_merge.dta", nogen
	erase "$output/temp_merge.dta"
	drop id
	order country region wbcode year wbnum inclvl usaid ftf group
*rename/label variables lost in reshaping
	lab var data1 `"Urban proportion"'
		rename data1 urbprop
	lab var data2 `"Urban Population"'
		rename data2 urbpop
	lab var data3 `"Rural Population"'
		rename data3 rurpop
	lab var data4 `"Total Population"'
		rename data4 totpop
	lab var data5 `"Urban Growth Rate"'
		rename data5 urbgr
	lab var data6 `"Rural Growth Rate"'
		rename data6 rurgr
	lab var data7 `"Total Growth Rate"'
		rename data7 totgr
	lab var data8 `"Urban Poverty (Avg Annual Rate of Population Change over past 5 years)"'
		rename data8 urbpov
	lab var data9 `"Rural Poverty (Avg Annual Rate of Population Change over past 5 years)"'
		rename data9 rurpov
	lab var data10 `"Total Poverty (Avg Annual Rate of Population Change over past 5 years)"'
		rename data10 totpov
*export
	save "$output/urbanpovlong.dta", replace
	export excel "$excel/urbanpov.xlsx", firstrow(var) sheet("UN_countries_all") sheetreplace
		
*remove years outside out focus range
	drop if year<2009 | year>2012
*last occurance in range
	sort country year
	foreach x in tot urb rur {
		by country:egen `x'pov_latest_yr = max(year) if `x'pov!=.
			replace `x'pov_latest_yr = . if year!=`x'pov_latest_yr
		gen `x'pov_latest = `x'pov if `x'pov_latest_yr!=.
	}
	*end
	lab var totpov_latest_yr "Year of Lastest Total Poverty Observation"
	lab var totpov_latest "Latest Total Poverty Observation"
	lab var urbpov_latest_yr "Year of Lastest Urban Poverty Observation"
	lab var urbpov_latest "Latest Urban Poverty Observation"
	lab var rurpov_latest_yr "Year of Lastest Rural Poverty Observation"
	lab var rurpov_latest "Latest Rural Poverty Observation"

*encode string vars for collapsing - country and wbcode
	encode country, gen(ctry)
		drop country
		rename ctry country
		lab var country "Country"
		order country
	encode wbcode, gen(wbc)
		drop wbcode
		rename wbc wbcode
		lab var wbcode "World Bank Country Code"
		order country wbcode

*2010 figures
	foreach x in urbprop urbpop rurpop totpop{
		bysort country: egen `x'2010 = max(`x')
		replace `x'2010=. if totpov_latest==. & urbpov_latest==. & rurpov_latest==.
	}
	*end
	lab var urbprop2010 "Urban proportion (2010)"
	lab var urbpop2010 "Urban Population (2010)"
	lab var rurpop2010 "Rural Population (2010)"
	lab var totpop2010 "Total Population (2010)"

*collapse for 1 country observation in range
	*save variable labels
	foreach v of var * {
			local l`v' : variable label `v'
				if `"`l`v''"' == "" {
				local l`v' "`v'"
			}
	}
	collapse (max) wbcode region wbnum inclvl usaid ftf group totpov_latest_yr ///
		totpov_latest urbpov_latest_yr urbpov_latest rurpov_latest_yr ///
		rurpov_latest urbprop2010 urbpop2010 rurpop2010 totpop2010, by(country)
	*re-attach variable labels
	foreach v of var * {
        label var `v' "`l`v''"
	}
	*end
	
	*re-attach label definitions
	lab val region region
	lab val inclvl inclvl
	lab val ftf usaid yn
	lab val group group
	
	*reorder
	order country wbcode region wbnum inclvl usaid ftf group urbprop2010 ///
		urbpop2010 rurpop2010 totpop2010 totpov_latest totpov_latest_yr ///
		urbpov_latest urbpov_latest_yr rurpov_latest rurpov_latest_yr

*save
	save "$output/urbanpov_reg.dta", replace
	export excel "$excel/urbanpov.xlsx", firstrow(var) sheet("countries") sheetreplace
	
********************************************************************************
********************************************************************************

use "$output/urbanpov_reg.dta", clear

// REGIONAL DATA //

*numer of poor
	gen rurpov_num = rurpov_latest * rurpop2010 
		lab var rurpov_num "Number of rural poor"
	gen urbpov_num = urbpov_latest * urbpop2010 
		lab var urbpov_num "Number of urban poor"
	gen totpov_num = totpov_latest * totpop2010
		lab var totpov_num "Number of total poor"

*country level urban share of poor
	gen urbsh = (urbpov_num/totpov_num)*100
		lab var urbsh "Urban share of poverty"
		
*number of countries (non-missing) for necessary variables
	*bysort region: egen cntry_count = count(country) ///
		*if totpov_latest!=. & urbpov_latest!=. & rurpov_latest!=.
	*lab var cntry_count "Number of countries in region (with non-missing poverty data)"
	
	bysort region: egen cntry_count_rurpov = count(country)	if rurpov_latest!=.
		lab var cntry_count_rurpov "Number of countries in region (with non-missing rural poverty data)"
	bysort region: egen cntry_count_urbpov = count(country)	if urbpov_latest!=.
		lab var cntry_count_rurpov "Number of countries in region (with non-missing urban poverty data)"
	bysort region: egen cntry_count_urbsh = count(country)	if urbsh!=.
		lab var cntry_count_rurpov "Number of countries in region (with non-missing urban share data)"

		
*collapse to regional level
	*save variable labels
		foreach v of var * {
				local l`v' : variable label `v'
					if `"`l`v''"' == "" {
					local l`v' "`v'"
				}
		}
	*end
	collapse (max) cntry_count_* (sum) rurpov_latest urbpov_latest ///
		rurpov_num urbpov_num totpov_num urbsh rurpop2010 urbpop2010, by(region) 
	drop if region==.
	*re-attach variable labels
		foreach v of var * {
			label var `v' "`l`v''"
		}
		*end
*Regional average headcounts
	gen reg_avghc_rur = rurpov_latest/cntry_count_rurpov
		lab var reg_avghc_rur "Regional average rural headcount"
	gen reg_avghc_urb = urbpov_latest/cntry_count_urbpov
		lab var reg_avghc_urb "Regional average urban headcount"
	format reg_avghc* %9.1fc
		
*Regional headcounts
	gen reg_hc_rur = rurpov_num/rurpop2010
		lab var reg_hc_rur "Rural headcount for the region"
	gen reg_hc_urb = urbpov_num/urbpop2010
		lab var reg_hc_urb "Urban headcount for the region"
	format reg_hc* %9.1fc
	
*Urban share average
	
	gen reg_avgurbsh = urbsh/cntry_count_urbsh
		lab var reg_avgurbsh "Regional average urban share of poverty"
	gen reg_urbsh = (urbpov_num/totpov_num)*100
		lab var reg_urbsh "Regional urban share of poverty"
	format reg_avgurbsh reg_urbsh %9.1fc

export excel region cntry_count* reg_avghc_rur reg_avghc_urb reg_hc_rur ///
	reg_hc_urb reg_avgurbsh reg_urbsh ///
	using "$excel/urbanpov.xlsx",sheet("regions") sheetreplace firstrow(var)
	 
********************************************************************************
********************************************************************************

// Figures //
	 
** Urban Percent by Region **

use "$output/urbanpovlong.dta", clear

* create average for each region & year
	egen region_yrly_avg = mean(urbprop), by(year region) 
		lab var region_yrly_avg "Avg % urban poor by region & year"
		
*graph regional trends (all developing, single plot)
	sort region year
	twoway (connected region_yrly_avg year if region==1, msymbol(O)) ///
		(connected region_yrly_avg year if region==2, msymbol(D)) ///	
		(connect region_yrly_avg year if region==3, msymbol(T)) ///
		(connect region_yrly_avg year if region==4, msymbol(S)) ///
		(connect region_yrly_avg year if region==5, msymbol(O) mfcolor(white)) /// 
		(connect region_yrly_avg year if region==6, msymbol(D) mfcolor(white)), ///
		title("Mean Urban Population Percentage") ///
		sub("Developing countries, 1950-2050") ///
		note("Sources: UN, World Bank/WDI, & USAID") 	///
		legend(order (1 "East Asia & Pacific" 2 "Europe & Central Asia" ///
			3 "Latin America & Caribbean" 4 "Middle East & North Africa" ///
			5 "South Asia" 6 "Sub-Saharan Africa") ///
		size(small)) ///
		ytitle("Percent") ///
		ylabel(0(20)80) ///
		yline(50, lpattern(dash) lcolor(gs12)) /// 
		xlabel(1950(25)2050) ///
		xline(2015, lcolor(gs14))
	graph export "$graph/urbanpop_reg_alldev.pdf", replace

*save variable labels
		foreach v of var * {
				local l`v' : variable label `v'
					if `"`l`v''"' == "" {
					local l`v' "`v'"
				}
		}
	*end	
* create regional urban proportion
	collapse (sum) urbpop totpop, by(year region)
	
*re-attach variable labels
		foreach v of var * {
			label var `v' "`l`v''"
		}
		*end
*clean
	drop if region==.
	drop if urbpop==0
	
* create regional urban proportion variable
	gen reg_urbprop = (urbpop/totpop)*100
		lab var reg_urbprop "Regional Proportion of Pop in Urban areas"

*graph regional trends (all developing, single plot)
	sort region year
	twoway (connected reg_urbprop year if region==1, msymbol(O)) ///
		(connected reg_urbprop year if region==2, msymbol(D)) ///	
		(connect reg_urbprop year if region==3, msymbol(T)) ///
		(connect reg_urbprop year if region==4, msymbol(S)) ///
		(connect reg_urbprop year if region==5, msymbol(O) mfcolor(white)) /// 
		(connect reg_urbprop year if region==6, msymbol(D) mfcolor(white)), ///
		title("Regional Urban Population Percentage") ///
		sub("Developing countries, 1950-2050") ///
		note("Sources: UN, World Bank/WDI, & USAID") 	///
		legend(order (1 "East Asia & Pacific" 2 "Europe & Central Asia" ///
			3 "Latin America & Caribbean" 4 "Middle East & North Africa" ///
			5 "South Asia" 6 "Sub-Saharan Africa") ///
		size(small)) ///
		ytitle("Percent") ///
		ylabel(0(20)80) ///
		yline(50, lpattern(dash) lcolor(gs12)) /// 
		xlabel(1950(25)2050) ///
		xline(2015, lcolor(gs14))
		graph export "$graph/urbanpop_reglvl_alldev.pdf", replace
