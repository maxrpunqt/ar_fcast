{smcl}
{title:Title}

{phang}{bf: ar_fcast {hline 2} Forecast time series with autoregressive dependent variable}


{marker syntax}{...}
{title:Syntax}

{p 8 16 2}
{opt ar_fcast} depvar L#depvar fcast_period , {cmdab:l:ag}(#) [{cmdab:rmse}]

{synoptset 20 tabbed}{...}
{synopthdr}
{synoptline}
{synopt :{opt lag(#)}}set the lag equal to integer #, which is equal to one or greater {p_end}
{synopt :{opt rmse}}compute root mean squared error and R square for the non-missing {it: fcast_period} values {p_end}

{synoptline}
{p 4 6 2}
A panel variable and a time variable must be specified. Use {helpb xtset}. Estimation results must already be stored in memory. Use {helpb estimates query} to verify that the current estimates are stored .{p_end}


{marker description}{...}
{title:Description}

{pstd}
{cmd: ar_fcast} predicts recursively the outcome variable {it:depvar}, using as independent variables: {it:L#depvar}, the lagged {it:depvar}, and other covariates from the initial estimation model. The prediction is performed for a user-specified forecast period {it:fcast_period}, which should be  a numerical sequence starting with 1. Please note that the initial regression should not be run with the lag operator but by creating a lagged variable with the following name structure: {it:L#depvar}.

{synoptline}
{p2colreset}{...}


{marker examples}{...}
{title:Examples}

{pstd}Setup{p_end}

{phang2}{cmd:. webuse invest2, clear}{p_end}
{phang2}{cmd:. xtset company time}{p_end}
{phang2}{cmd:. gen L1invest = L1.invest}{p_end}
{phang2}{cmd:. qreg invest L1invest market stock i.company if time<=10, quantile(0.5)}{p_end}
{phang2}{cmd:. bys company: gen fcast_period = _n-10 if _n>10}{p_end}
{phang2}{cmd: }{p_end}

{pstd}Resursive prediction{p_end}

{phang2}{cmd: }{p_end}
{phang2}{cmd:. ar_fcast invest L1invest fcast_period, lag(1)}{p_end}
{phang2}{cmd: }{p_end}
{phang2}{cmd: }{p_end}

{pstd}Same result with manual calculation{p_end}

{phang2}{cmd: }{p_end}
{phang2}{cmd:. levelsof company, local(companies)}{p_end}
{phang2}{cmd:. gen company_fe = .}{p_end}
{phang2}{cmd:. foreach var of local companies {c -(} }{p_end}
{phang2}{cmd:      {space 5} replace company_fe = _b[`var'.company] if company== `var' }{p_end}
{phang2}{cmd: {space 1} {c )-} }{p_end}

{phang2}{cmd:. gen _invest_fc_man = invest if _fcast_period < 1}{p_end}
{phang2}{cmd:. bys company: replace _invest_fc_man = _invest_fc_man[_n-1]*_b[L1invest] + market*_b[market] + stock*_b[stock] + company_fe + _b[_cons] if _fcast_period >=1}{p_end}
{phang2}{cmd:. assert round(_invest_fc,0.01) == round(_invest_fc_man,0.01)}{p_end}
{phang2}{cmd: }{p_end}

{pstd}Computing the RMSE for the forecast period{p_end}

{phang2}{cmd: }{p_end}
{phang2}{cmd:. ar_fcast invest L1invest fcast_period, lag(1) rmse}{p_end}
{phang2}{cmd: }{p_end}

{pstd}Same result with manual calculation{p_end}

{phang2}{cmd:. qui gen e = invest - _invest_fc_man if !missing(fcast_period)}{p_end}
{phang2}{cmd:. qui gen e2 = e*e}{p_end}

{phang2}{cmd:. qui corr invest _invest_fc_man if !missing(fcast_period)}{p_end}
{phang2}{cmd:. display "Forecast period's R^2 = " %05.3f =`r(rho)'^2}{p_end}

{phang2}{cmd:. qui summ e2 if !missing(fcast_period), meanonly}{p_end}
{phang2}{cmd:. display "Forecast period's RMSE = " =sqrt(`r(mean)')}{p_end}



{hline}

{title:Remarks}

{p 4 12 6} The initial regression variables must have the same names as the input variables. {p_end}

{p 4 12 6} E.g., for "{cmd:reg} {it:y L1y} x" -> "{cmd:ar_fcast} {it:y L1y} fcast_period , lag(1)" {p_end}


{title:Stored results}

{pstd}
{cmd:ar_fcast} stores the following in {cmd:e()}:

{synoptset 20 tabbed}{...}
{p2col 5 20 24 2: Scalars}{p_end}
{synopt:{cmd:e(rmse)}}RMSE{p_end}
{synopt:{cmd:e(r2)}}R square {p_end}


{title:Author}

{phang}
{cmd:Max R.}, Frankfurt am Main, Germany.{break}
 E-mail: {browse "mailto:kerrydu@sdu.edu.cn":maxrpunqt@gmail.com}. {break}

