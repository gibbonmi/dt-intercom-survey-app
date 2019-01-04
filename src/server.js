/* This is code related to the glitch environment setup */
const express = require('express');
const bodyParser = require('body-parser');
const app = express();

/* let Canvas = require('./components/Canvas'); */



app.use(bodyParser.urlencoded({ extended: true }));
app.use(bodyParser.json());
app.use(express.static(__dirname));

const appPort = 3002;

// http://expressjs.com/en/starter/basic-routing.html
app.get('/healthcheck', (req, res) => res.sendStatus(200));
app.get('/', function(request, response) {
    response.sendFile(__dirname + '/views/index.html');
});

const listener = app.listen(appPort, () => {
    console.log('Your app is listening on port ' + appPort);
});

/* 
Template to create a canvas and add components and stored data as needed
e.g. 
Step 1: Create the canvas object
let my_canvas = new CreateCanvas();
Step 2: Add one or more components as needed
my_canvas.add_components({ type: "input", id: "my_input", label: "Add some input", 
                          action: { type: "submit" } });
Step 3: optionally add some stored data if you need it
my_canvas.add_stored_data({some_data: "this data"})
*/
class CreateCanvas{

    /* this is the main canvas object which you will use when creating an app */
    constructor(){
        this.canvas = {
            canvas: {
                content: {
                    components: [],
                },
                stored_data: {},
            },
        };
    }

    /* Call this method to add components to the app */
    add_components(comp) {
        this.canvas.canvas.content.components.push(comp);
    };

    /* Call this method to add stored data to the app */
    add_stored_data(storeObj){
        this.canvas.canvas.stored_data = storeObj;
    }

    /* call this when you want return the canvas object to send it to Intercom */
    get_canvas() {
        return(this.canvas);

    }
}

/* 
  This is an endpoint that Intercom will POST HTTP request when the card needs to be initialized.
  This can happen when your teammate inserts the app into a conversation composer, Messenger home settings or User Message.
  Params sent from Intercom contains for example `card_creation` parameter that was formed by your `configure` response.
*/
app.post('/initialize', (request, response) => {
    const body = request.body;
    /* Create the canvas based on the teammates configurations */
    /* Create a new question canvas */
    let surveyCanvas = new CreateCanvas();
    /* Create the single select option to get the rating */
    // surveyCanvas.add_components({type: "single-select",
    //     id: "rating",
    //     label: "Would you recommend Dynatrace to a friend or colleague",
    //     options: [
    //         {type: "option", id: "one", text: "1"},
    //         {type: "option", id: "two", text: "2"},
    //         {type: "option", id: "three", text: "3"},
    //         {type: "option", id: "four", text: "4"},
    //         {type: "option", id: "five", text: "5"},
    //         {type: "option", id: "six", text: "6"},
    //         {type: "option", id: "seven", text: "7"},
    //         {type: "option", id: "eight", text: "8"},
    //         {type: "option", id: "nine", text: "9"},
    //         {type: "option", id: "ten", text: "10"}
    //     ]
    // });

    surveyCanvas.add_components({
        type: "dropdown",
        id: "rating",
        label: "Dynatrace made it easy to solve your issue",
        options: [
            {type: "option", id: "one", text: "Strongly disagree"},
            {type: "option", id: "two", text: "Disagree"},
            {type: "option", id: "three", text: "Somewhat disagree"},
            {type: "option", id: "four", text: "Neutral"},
            {type: "option", id: "five", text: "Somewhat agree"},
            {type: "option", id: "six", text: "Agree"},
            {type: "option", id: "seven", text: "Strongly\nagree"}
        ],
        value: "seven"
    });
    /* Create the question to explain the rating */
    surveyCanvas.add_components({type: "input",
        id: "feedback",
        label: "Please provide a reason if possible for your rating"
    });
    /* And finally add a button to submit both user inputs */
    surveyCanvas.add_components({ type: "button",
            id: "question_submit",
            label: "Submit form",
            action: {
                type: "submit"}
        }
    );



    response.send(surveyCanvas.get_canvas());
});

/* 
  This is an endpoint that Intercom will POST HTTP request whenever your customer interacts with the card.
  Interesting pattern used here is to use `current_canvas` and `stored_data` on this canvas to fetch some 
  detailed info about the card straight from Intercom instead of your backend.
*/
app.post('/submit', (request, response) => {
    const body = request.body;
    console.log(body);
    switch(body.component_id) {
        case 'question_submit':
            let submitCanvas = new CreateCanvas();
            submitCanvas.add_components({
                type: "text",
                text: "Thanks you for your feedback",
                align: "center",
                style: "header" });
            response.send(submitCanvas.get_canvas());
            break;
        default:
            /* We should not go in here */
            let wrongCanvas = new CreateCanvas();
            wrongCanvas.add_components({
                type: "text",
                text: "This should not happen!!",
                align: "center",
                style: "header" });
            response.send(wrongCanvas.get_canvas());
            break;
    }
});