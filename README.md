# ar_fcast
Forecast time series with autoregressive dependent variable

Description
ar_fcast predicts recursively the outcome variable depvar, using as independent variables: L#depvar, the
    lagged depvar, and other covariates from the initial estimation model. The prediction is performed for a
    user-specified t period fcast_period, which should be a numerical sequence starting with 1. Please note
    that the initial regression should not be run with the lag operator but by creating a lagged variable
    with the following name structure: L#depvar.
    
Syntax
ar_fcast depvar L#depvar fcast_period , lag(#) [rmse]
