*! Version 1.0 
* Compute out-of-sample forecasts with auto-regressive dependent variable
* for panel data
* By Max R., maxrpunqt@gmail.com
* 15 May 2021

capture program drop ar_fcast
program define ar_fcast 
	version 14.1
	syntax varlist(min=3 max=3) , Lag(integer)
	*syntax invest L1invest fcast_period, Lag(1)
	
	*Check basic requirements
	if (`lag'<=0 ) {
			disp as red "lag should be set equal to one or greater"
	}
	_xt, trequired 
	local id=r(ivar)
	local time=r(tvar)

	marksample touse, novarlist

	qui tab `id' if `touse', nofreq
	local Ncross=r(r)
	if (`Ncross'<=1){
	   disp as red "Error: The number of individuals should be greater than one!"
	   error 2000
	} 
	*Define variables
	qui local depvar `1'
	qui local lagvar `2'
	qui local fcast_period = subinstr("`3'", ",","",.)
	qui di "`fcast_period'"
	qui gen _fcast_period = `fcast_period'
	qui label variable _fcast_period "Forecast period, adjusted for number of lags"
	
	foreach l of numlist 1/`lag' {
		qui bys company: replace _fcast_period = _fcast_period[_n+`l'] - `l' if _fcast_period[_n+`l'] == 1
	}
	

	qui bys `id': gen _`depvar'_fc = `depvar' if _fcast_period < 1
	qui label variable _`depvar'_fc "Forecasted values, starting with actual observations in _fcast_period<1"
	
	*Run recursive prediction
	di "Start recursive prediction."
	qui clonevar `lagvar'_orig = `lagvar'

	qui replace `lagvar' = L`lag'._`depvar'_fc
	
	qui predict `depvar'_predict, xb
	qui replace _`depvar'_fc = `depvar'_predict if missing(_`depvar'_fc)
	qui clonevar clone = `depvar'_predict
	qui drop `depvar'_predict


	qui local more 1
	qui local cnt 1
	while `more' {
		*run loop util all forecast periods are filled up with predictions
		di "Iteration step: `cnt'"
		
		qui replace `lagvar' = L`lag'._`depvar'_fc
		qui predict `depvar'_predict, xb
		qui replace _`depvar'_fc = `1'_predict if missing(_`depvar'_fc)
		qui count if `depvar'_predict != clone
		qui local more = r(N)
		qui drop clone
		qui clonevar clone = `depvar'_predict
		qui drop `depvar'_predict
		qui local cnt = `cnt' + 1
	}
	*prepare final results
	qui drop clone
	qui replace `lagvar'  = `lagvar'_orig
	qui drop `lagvar'_orig
	*bro*

	qui gen `depvar'_fc = _`depvar'_fc
	*replace `depvar'_fc = . if `fcast_period' != _fcast_period
	qui replace `depvar'_fc = . if `fcast_period'==.
	
	qui order _*, last 
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

ar_fcast invest L`lag'invest fcast_period, lag(`lag')

 
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
