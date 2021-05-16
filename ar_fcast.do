********************************************************************************
* Works, Lag: any, 3-var syntax, including input checks
* V 1.1: include RMSE
********************************************************************************

webuse invest2, clear
xtset company time

local lag = 1
gen L`lag'invest = L`lag'.invest
qreg invest L`lag'invest market stock i.company if time<=10, quantile(0.5)
bys company: gen fcast_period = _n-10 if _n>10


capture program drop ar_fcast
program define ar_fcast, eclass
	version 14.1
	syntax varlist(min=3 max=3) , Lag(integer) [rmse]
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
	capture drop _fcast_period
	qui gen _fcast_period = `fcast_period'
	qui label variable _fcast_period "Forecast period, adjusted for number of lags"
	
	foreach l of numlist 1/`lag' {
		qui bys company: replace _fcast_period = _fcast_period[_n+`l'] - `l' if _fcast_period[_n+`l'] == 1
	}
	
	capture drop _`depvar'_fc
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
		*di "Iteration step: `cnt'"
		
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
	di "End recursive prediction."
	*prepare final results
	qui drop clone
	qui replace `lagvar'  = `lagvar'_orig
	qui drop `lagvar'_orig
	*bro*
	
	capture drop `depvar'_fc
	qui gen `depvar'_fc = _`depvar'_fc
	*replace `depvar'_fc = . if `fcast_period' != _fcast_period
	qui replace `depvar'_fc = . if `fcast_period'==.
	
	qui order _*, last 
	
	if "`rmse'"=="rmse" {
		* do not subtract one
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


ar_fcast invest L`lag'invest fcast_period, lag(`lag') rmse

*ar_fcast invest L1invest fcast_period, lag(1) rmse

di e(rmse)
di e(r2)
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


qui gen e = invest - _invest_fc_man if !missing(fcast_period)
qui gen e2 = e*e

qui corr invest _invest_fc_man if !missing(fcast_period)
display "Forecast period's R^2 = " %05.3f =`r(rho)'^2

qui summ e2 if !missing(fcast_period), meanonly
display "Forecast period's RMSE = " =sqrt(`r(mean)')

bro*


/*
********************************************************************************
* Works, Lag: any, 3-var syntax, including input checks, V 1.0
********************************************************************************

webuse invest2, clear
xtset company time

local lag = 1
gen L`lag'invest = L`lag'.invest
qreg invest L`lag'invest market stock i.company if time<=10, quantile(0.5)
bys company: gen fcast_period = _n-10 if _n>10


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


bro*

/*
********************************************************************************
* Works, Lag: any, 3-var syntax, including input checks
********************************************************************************


webuse invest2, clear
xtset company time

local lag = 1
gen L`lag'invest = L`lag'.invest
qreg invest L`lag'invest market stock i.company if time<=10, quantile(0.5)
bys company: gen fcast_period = _n-10 if _n>10

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


bro*
/*
********************************************************************************
* Works, Lag: any, 3-var syntax, including input checks
********************************************************************************


webuse invest2, clear
xtset company time

local lag = 1
gen L`lag'invest = L`lag'.invest
qreg invest L`lag'invest market stock i.company if time<=10, quantile(0.5)
bys company: gen fcast_period = _n-10 if _n>10

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
		*di "Iteration step: `cnt'"
		
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


bro*

/*
********************************************************************************
* Works, Lag: any, 3-var syntax
********************************************************************************


webuse invest2, clear
xtset company time

local lag = 1
gen L`lag'invest = L`lag'.invest
qreg invest L`lag'invest market stock i.company if time<=10, quantile(0.5)
bys company: gen fcast_period = _n-10 if _n>10

program drop ar_fcast
program define ar_fcast 
	version 14.1
	syntax varlist(min=3 max=3) , Lag(integer)
	*syntax invest L1invest fcast_period, Lag(1)
	qui local depvar `1'
	qui local lagvar `2'
	qui local fcast_period = subinstr("`3'", ",","",.)
	qui di "`fcast_period'"
	qui gen _fcast_period = `fcast_period'
	qui label variable _fcast_period "Forecast period, adjusted for number of lags"
	
	foreach l of numlist 1/`lag' {
		qui bys company: replace _fcast_period = _fcast_period[_n+`l'] - `l' if _fcast_period[_n+`l'] == 1
	}
	
	qui xtset
	qui local panelvar = r(panelvar)
	qui bys `panelvar': gen _`depvar'_fc = `depvar' if _fcast_period < 1
	qui label variable _`depvar'_fc "Forecasted values, starting with actual observations in _fcast_period<1"

	qui clonevar `lagvar'_orig = `lagvar'

	qui replace `lagvar' = L`lag'._`depvar'_fc
	
	qui predict `depvar'_predict, xb
	qui replace _`depvar'_fc = `depvar'_predict if missing(_`depvar'_fc)
	qui clonevar clone = `depvar'_predict
	qui drop `depvar'_predict


	qui local more 1
	qui local cnt 1
	while `more' {

		*di "Iteration step: `cnt'"
		
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

	qui drop clone
	qui replace `lagvar'  = `lagvar'_orig
	qui drop `lagvar'_orig
	*bro*

	qui gen `depvar'_fc = _`depvar'_fc
	*replace `depvar'_fc = . if `fcast_period' != _fcast_period
	qui replace `depvar'_fc = . if `fcast_period'==.

	qui order _*, last 
end


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


bro*

/*
********************************************************************************
* Works, Lag: any, procedure related variables marked with _
********************************************************************************


webuse invest2, clear
xtset company time

local lag = 4
gen L`lag'invest = L`lag'.invest
qreg invest L`lag'invest market stock i.company if time<=10, quantile(0.5)
bys company: gen fcast_period = _n-10 if _n>10


gen _fcast_period = fcast_period
foreach l of numlist 1/`lag' {
	bys company: replace _fcast_period = _fcast_period[_n+`l'] - `l' if _fcast_period[_n+`l'] == 1
}


bys company: gen _invest_fc = invest if _fcast_period < 1

clonevar L`lag'invest_orig = L`lag'invest 
replace L`lag'invest = L`lag'._invest_fc
predict invest_predict, xb
replace _invest_fc = invest_predict if missing(_invest_fc)
clonevar clone = invest_predict
drop invest_predict


local more 1
local cnt 1
while `more' {

	di "Iteration step: `cnt'"
	
	qui replace L`lag'invest = L`lag'._invest_fc
	qui predict invest_predict, xb
	qui replace _invest_fc = invest_predict if missing(_invest_fc)
	qui count if invest_predict != clone
	qui local more = r(N)
	qui drop clone
	qui clonevar clone = invest_predict
	qui drop invest_predict
	local cnt = `cnt' + 1
}

drop clone
replace L`lag'invest  = L`lag'invest_orig
drop L`lag'invest_orig
bro*

gen invest_fc = _invest_fc
replace invest_fc = . if fcast_period==.
order _*, last 

 
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





/*
********************************************************************************
* Works, Lag: any
********************************************************************************

webuse invest2, clear
xtset company time

local lag = 4
gen L`lag'invest = L`lag'.invest
qreg invest L`lag'invest market stock i.company if time<=10, quantile(0.5)
bys company: gen fcast_period = _n-10 if _n>10


gen _fcast_period = fcast_period
foreach l of numlist 1/`lag' {
	bys company: replace _fcast_period = _fcast_period[_n+`l'] - `l' if _fcast_period[_n+`l'] == 1
}


bys company: gen invest_fc = invest if _fcast_period < 1

clonevar L`lag'invest_orig = L`lag'invest 
replace L`lag'invest = L`lag'.invest_fc
predict invest_predict, xb
replace invest_fc = invest_predict if missing(invest_fc)
clonevar clone = invest_predict
drop invest_predict


local more 1
local cnt 1
while `more' {

	di "Iteration step: `cnt'"
	
	qui replace L`lag'invest = L`lag'.invest_fc
	qui predict invest_predict, xb
	qui replace invest_fc = invest_predict if missing(invest_fc)
	qui count if invest_predict != clone
	qui local more = r(N)
	qui drop clone
	qui clonevar clone = invest_predict
	qui drop invest_predict
	local cnt = `cnt' + 1
}

drop clone
replace L`lag'invest  = L`lag'invest_orig
drop L`lag'invest_orig
bro*


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
assert round(invest_fc,0.01) == round(_invest_fc_man,0.01)




/*
********************************************************************************
* Works, Lag: 1
********************************************************************************

webuse invest2, clear
xtset company time

local lag = 1
gen L`lag'invest = L`lag'.invest
qreg invest L`lag'invest market stock i.company if time<=10, quantile(0.5)
bys company: gen fcast_period = _n-10 if _n>=10


bys company: gen invest_fc = invest if fcast_period == 0

clonevar L`lag'invest_orig = L`lag'invest 
replace L`lag'invest = L`lag'.invest_fc
predict invest_predict, xb
replace invest_fc = invest_predict if missing(invest_fc)
clonevar clone = invest_predict
drop invest_predict


local more 1
local cnt 1
while `more' {

	di "Iteration step: `cnt'"
	
	qui replace L`lag'invest = L`lag'.invest_fc
	qui predict invest_predict, xb
	qui replace invest_fc = invest_predict if missing(invest_fc)
	qui count if invest_predict != clone
	qui local more = r(N)
	qui drop clone
	qui clonevar clone = invest_predict
	qui drop invest_predict
	local cnt = `cnt' + 1
}

drop clone
replace L`lag'invest  = L`lag'invest_orig
drop L`lag'invest_orig
bro*


// Manual calculation:

qreg invest L`lag'invest market stock i.company if time<=10, quantile(0.5)
levelsof company, local(companies)
gen company_fe = . 
foreach var of local companies {
	replace company_fe = _b[`var'.company] if company== `var'
}

gen _invest_fc_man = invest if fcast_period == 0
bys company: replace _invest_fc_man = _invest_fc_man[_n-`lag']*_b[L`lag'invest] + market*_b[market] + stock*_b[stock] + company_fe + _b[_cons] if fcast_period > 0
drop company_fe
assert round(invest_fc,0.01) == round(_invest_fc_man,0.01)







/*
********************************************************************************
* Works
********************************************************************************
webuse invest2, clear
xtset company time
reg invest L1.invest market stock i.company if time<=10
bys company: gen fcast_period = _n-10 if _n>=10

bys company: gen invest_fc = invest if fcast_period == 0

clonevar invest_orig = invest 

replace invest = invest_fc
predict invest_predict, xb
replace invest_fc = invest_predict if missing(invest_fc)
clonevar clone = invest_predict
drop invest_predict
replace invest = invest_fc


local more 1
while `more' {
	di "Iteration step: `more'"
	replace invest = invest_fc
	predict invest_predict, xb
	replace invest_fc = invest_predict if missing(invest_fc)
	count if invest_predict != clone
	local more = r(N)
	drop clone
	clonevar clone = invest_predict
	drop invest_predict

}
drop clone
replace invest = invest_orig
drop invest_orig
bro*


// Manual calculation:
gen linvest = L1.invest
reg invest linvest market stock i.company if time<=10
levelsof company, local(companies)
gen company_fe = . 
foreach var of local companies {
	replace company_fe = _b[`var'.company] if company== `var'
}

gen _invest_fc_man = invest if fcast_period == 0
bys company: replace _invest_fc_man = _invest_fc_man[_n-1]*_b[linvest] + market*_b[market] + stock*_b[stock] + company_fe + _b[_cons] if fcast_period > 0

assert round(invest_fc,0.01) == round(_invest_fc_man,0.01)
