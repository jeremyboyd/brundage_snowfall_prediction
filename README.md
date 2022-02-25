# Using LSTM models to predict snowfall

Have you seen this page?
<br>
<br>
https://powderbuoy.com
<br>
<br>
The authors claim that activity at a specific weather buoy northwest of Kauai can predict snowstorms in Utah and other Mountain West locations. Specifically, if there's a buoy pop--i.e., if wave height measured at the buoy suddenly increases--this predicts snow in Utah two weeks later.

I've been a skier and snowboarder since I was a kid. When I heard this idea I was super excited. It's basically a method for doing long term snowfall forcasts which, if accurate, would allow you to plan time off from work in order to be on the mountain when big storms hit.

I wanted to find out whether there was really anything to the buoy pop hypothesis. So I collected a bunch of timeseries data: wave heights from the Kauai buoy, and snowfall, temperature, and other weather data from recording stations at Snowbird, Utah and Brundage Mountain, Idaho. I used all of this to train an LSTM models to predict snowfall on the two mountains. Long story short: predictive accuracy did not improve with inclusion of the wave height data from Kauai.

This doesn't necessarily mean that Pacific wave heights can't be used to predict snowfall in the Mountain West. But it does seem to undermine a simple formulation of the buoy pop hypothesis--that there's a single buoy that's key to understanding snowfall two weeks later and thousands of miles away.
