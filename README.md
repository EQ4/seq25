# SEQ25A sequencer inspired by [SEQ24][s].[s]: http://www.filter24.org/seq24/## SetupIf you already have [lineman][l] installed, then just clone the app and run:[l]: http://linemanjs.com```$ npm install$ lineman run```Now go to http://localhost:8000 and you should see the app running.## TODO* clear part* clear song* save song* independent loop repeat points* instrument envelopes* note velocity adjustment* performance issue on note add* quantization control* add part on first click, not on song create# versioningYou visit seq25.com for the first time- a new song has been added to your local storage and your url is updated- a working copy song has been addedYou modify the song- the working copy song is mutatedYou commit the song- the working copy song is copied to a new song.- the url is updated and history is modified to reflect the id of the new song- your working copy of the song is the same as your newly created songYou only ever have one working copy song.## Sharingurl indicates that I am on my local song.Committing my song puts an id in my url.I am now on a sharable link.When I diverge from this link the url indicates that I am on a local song again.While you edit this song, all changes are persisted to the localstorage id in your urlYou click commit- the loca