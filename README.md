# Set card game app

This project consists of a Flutter app that makes use of object detection to provide suggestions for the
[card game "Set"](https://en.wikipedia.org/wiki/Set_(card_game)).

The app allows taking an image of a laid-out collection of cards.
The four properties of each card in the image will be identified: color, shape, filling, and count.
After determining the cards in the image, the app will calculate if there are any possible "sets".
A set consists of exactly three cards, where for each property one of the following must hold:
either all cards have the same value for that property (e.g. three green cards) or each card must have a different
value for that property (e.g. green, purple, red).
