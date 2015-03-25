***************************
**     Urban Poverty     **
**       Addendum        **
**     Aaron Chafetz     **
**     USAID/E3/PLC      **
**     Mar 25, 2014      **
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

********************************************************************************
********************************************************************************

// REGIONAL DATA //
		
*number of countries (non-missing) in region
	bysort region: egen cntry_count = count(country) ///
		if totpov_latest!=. & urbpov_latest!=. & rurpov_latest!=.
	lab var cntry_count "Number of countries in region (with non-missing poverty data)"
	
*numer of poor
	gen rurpov_num = rurpov_latest * rurpop2010 
		lab var rurpov_num "Number of rural poor"
	gen urbpov_num = urbpov_latest * urbpop2010 
		lab var urbpov_num "Number of urban poor"
		
*collapse to regional level
	*save variable labels
		foreach v of var * {
				local l`v' : variable label `v'
					if `"`l`v''"' == "" {
					local l`v' "`v'"
				}
		}
	*emd
	collapse (max) cntry_count (sum) rurpov_latest urbpov_latest ///
		rurpov_num urbpov_num rurpop2010 urbpop2010, by(region) 
	drop if region==.
	*re-attach variable labels
		foreach v of var * {
			label var `v' "`l`v''"
		}
		*end
*Regional average headcounts
	gen reg_avghc_rur = rurpov_latest/cntry_count
		lab var reg_avghc_rur "Regional average rural headcount"
	gen reg_avghc_urb = urbpov_latest/cntry_count
		lab var reg_avghc_urb "Regional average urban headcount"
	format reg_avghc* %9.1fc
		
*Regional headcounts
	gen reg_hc_rur = rurpov_num/rurpop2010
		lab var reg_hc_rur "Rural headcount for the region"
	gen reg_hc_urb = urbpov_num/urbpop2010
		lab var reg_hc_urb "Urban headcount for the region"
	format reg_hc* %9.1fc
