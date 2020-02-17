-> day_2


=== day_2 ====

Another day
-> generic_sleep (-> waking_up_tired )

=== sleeping_in_hut ===
	You lie down and close your eyes.
	-> generic_sleep (-> waking_in_the_hut)

===	 generic_sleep (-> waking)
	You sleep perchance to dream etc. etc.
	-> waking

=== waking_up_tired ===
    You didn't sleep
    -> DONE

=== waking_in_the_hut ===
	You get back to your feet, ready to continue your journey.
	-> DONE