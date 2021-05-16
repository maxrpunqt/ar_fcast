{smcl}
{title:Title}

{phang}{bf: ar_fcast {hline 2} Forecast time series with autoregressive dependent variable}


{marker syntax}{...}
{title:Syntax}

{p 8 16 2}
{opt ar_fcast} depvar L#depvar fcast_period , {cmdab:l:ag}(#)

{synoptset 20 tabbed}{...}
{synopthdr}
{synoptline}
{synopt :{opt lag(#)}}set the {it:lag} equal to one or greater {p_end}
{synoptline}
{p 4 6 2}
A panel variable and a time variable must be specified. Use {helpb xtset}. Estimation results must already be stored in memory. Use {helpb estimates query}.{p_end}


{marker description}{...}
{title:Description}

{pstd}
{cmd: ar_fcast} predicts recursively the outcome variable {it:depvar}, using as independent variables: {it:L#depvar}, the lagged {it:depvar}, and other covariates from the initial estimation model. The prediction is performed for a user-specified forecast period {it:fcast_period}, which should be  a numerical sequence starting with 1. Please note that the initial regression should not be run with the lag operator but by creating a lagged variable with with the following name structure {it:L#depvar} (e.g., L1depvar if lag = 1).

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

{pstd}Manual calculation{p_end}

{phang2}{cmd: }{p_end}
{phang2}{cmd:. levelsof company, local(companies)}{p_end}
{phang2}{cmd:. gen company_fe = .}{p_end}
{phang2}{cmd:. foreach var of local companies {c -(} }{p_end}
{phang2}{cmd:      {space 5} replace company_fe = _b[`var'.company] if company== `var' }{p_end}
{phang2}{cmd: {space 1} {c )-} }{p_end}

{phang2}{cmd:. gen _invest_fc_man = invest if _fcast_period < 1}{p_end}
{phang2}{cmd:. bys company: replace _invest_fc_man = _invest_fc_man[_n-1]*_b[L1invest] + market*_b[market] + stock*_b[stock] + company_fe + _b[_cons] if _fcast_period >=1}{p_end}
{phang2}{cmd:. assert round(_invest_fc,0.01) == round(_invest_fc_man,0.01)}{p_end}

{hline}


{title:Authors}

{phang}
{cmd:Max R.}, Frankfurt, Germany.{break}
 E-mail: {browse "mailto:kerrydu@sdu.edu.cn":maxrpunqt@gmail.com}. {break}

