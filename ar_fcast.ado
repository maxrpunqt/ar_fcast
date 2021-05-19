*! Version 1.3
* Compute out-of-sample forecasts with auto-regressive dependent variable
* for panel data
* By Max Riedel, max.ri3d3l@gmail.com
* Frankfurt am Main, Germany
* 19 May 2021


capture program drop ar_fcast
program define ar_fcast, eclass
	version 14.1
	syntax varlist(min=2 numeric), Lags(numlist min =1 integer) FCast_period(string) [rmse] [COrrection(string)] 

	qui local depvar: word 1 of `varlist'
	qui di "dep variable: `depvar'"
	
	qui local lagvars: list varlist- depvar
	qui di "`lagvars'"
	
	qui local lagvars_N: word count `lagvars'
	qui di "# lagged variables: `lagvars_N'"
	
	qui local lags_N = 0
	forval lagnum = 1/`:word count `lags''{
        qui di `lagnum'
		qui local lags_N = `lags_N' + 1
    }
	
	*Check basic requirements
	if ("`lagvars_N'"!="`lags_N'" ) {
			disp as red "Number of lagged depvars (`lagvars_N') does not equal the number of values (`lags_N') in the lags() option"
			error 102
	}
	
	qui _xt, trequired 
	qui local id=r(ivar)
	qui local time=r(tvar)
	
	qui marksample touse, novarlist

	qui tab `id' if `touse', nofreq
	qui local Ncross=r(r)
	if (`Ncross'<=1){
	   disp as red "Error: The number of individuals should be greater than one!"
	   error 2000
	} 

	*count number of lags and identify the largest lag
	if (`lags_N' == 1) {
		local max_lag = `lags'
		di "`max_lag'"
		}
		
	else if (`lags_N'>1) {
			local lags_c : subinstr local lags " " ",", all
			local max_lag = max(`lags_c')
			di "`max_lag'"
	}

	*adjust for lags by including values prior to starting point of forecast
	qui capture drop _fcast_period
	qui gen _fcast_period = `fcast_period'
	qui label variable _fcast_period "Forecast period, adjusted for number of lags"
	foreach l of numlist 1/`max_lag' {
		qui bys `id': replace _fcast_period = _fcast_period[_n+`l'] - `l' if _fcast_period[_n+`l'] == 1
	}


	qui capture drop _`depvar'_fc
	qui bys `id': gen _`depvar'_fc = `depvar' if _fcast_period < 1
	qui label variable _`depvar'_fc "Forecasted values, starting with actual observations in _fcast_period<1"

	*loop through all lagged dependent variables
	qui local i = 1
	foreach lag of local lags {
		qui local lagvar: word `i' of `lagvars'
		qui clonevar `lagvar'_orig = `lagvar'
		qui replace `lagvar' = L`lag'._`depvar'_fc
		qui local i = `i' + 1
	}

	qui predict `depvar'_predict, xb
	if "`correction'" != "" {
		qui replace `depvar'_predict = `depvar'_predict + `correction'
	}
	qui replace _`depvar'_fc = `depvar'_predict if missing(_`depvar'_fc)
	qui label variable _`depvar'_fc "Forecasted values, starting with actual observations in _fcast_period<1"

	*Run recursive prediction
	di "Start recursive prediction."
	qui clonevar clone = `depvar'_predict
	qui drop `depvar'_predict

	
	qui local more 1
	qui local cnt 1
	while `more' {

		di "Iteration step: `cnt'"
		qui local i = 1
		foreach lag of local lags {
			qui local lagvar: word `i' of `lagvars'
			qui replace `lagvar' = L`lag'._`depvar'_fc
			qui local i = `i' + 1
		}	
		qui predict `depvar'_predict, xb
		if "`correction'" != "" {
			qui replace `depvar'_predict = `depvar'_predict + `correction'
		}
		qui replace _`depvar'_fc = `depvar'_predict if missing(_`depvar'_fc)
		qui count if `depvar'_predict != clone
		qui local more = r(N)
		qui drop clone
		qui clonevar clone = `depvar'_predict
		qui drop `depvar'_predict
		qui local cnt = `cnt' + 1
	}
	
	di "End recursive prediction."
	*prepare final results

	qui drop clone
	qui local i = 1
	foreach lag of local lags {
		qui local lagvar: word `i' of `lagvars'
		qui replace `lagvar'  = `lagvar'_orig
		qui drop `lagvar'_orig
		qui local i = `i' + 1
	}
	*bro*
	qui capture drop `depvar'_fc
	qui gen `depvar'_fc = _`depvar'_fc
	qui replace `depvar'_fc = . if `fcast_period'==.
	qui order _*, last 
	
	if "`rmse'"=="rmse" {
		qui gen e = `depvar' - `depvar'_fc if !missing(`fcast_period')
		qui gen e2 = e*e
		
		qui corr `depvar' `depvar'_fc if !missing(`fcast_period')
		display "Forecast period's R^2 = " %05.3f =`r(rho)'^2
		ereturn scalar r2=`r(rho)'^2
		
		qui summ e2 if !missing(`fcast_period'), meanonly
		display "Forecast period's RMSE = " =sqrt(`r(mean)')
		ereturn scalar rmse=sqrt(`r(mean)')
		
		qui drop e e2
	}
end



********************************************************************************
* Begin: readily executable example
********************************************************************************
/*
webuse invest2, clear
xtset company time

local lag = 1
gen L`lag'invest = L`lag'.invest
qreg invest L`lag'invest market stock i.company if time<=10, quantile(0.5)
bys company: gen fcast_period = _n-10 if _n>10

*ar_fcast invest L`lag'invest fcast_period, lag(`lag')

ar_fcast invest L`lag'invest, lags(`lag') fc(fcast_period)

// Manual calculation:

qreg invest L`lag'invest market stock i.company if time<=10, quantile(0.5)
levelsof company, local(companies)
gen company_fe = . 
foreach var of local companies {
	replace company_fe = _b[`var'.company] if company== `var'
}

gen _invest_fc_man = invest if _fcast_period < 1
bys company: replace _invest_fc_man = _invest_fc_man[_n-`lag']*_b[L`lag'invest] + market*_b[market] + stock*_b[stock] + company_fe + _b[_cons] if _fcast_period >=1


drop company_fe
assert round(_invest_fc,0.01) == round(_invest_fc_man,0.01)

*/
********************************************************************************
* End: readily executable example
********************************************************************************
