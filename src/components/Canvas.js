class Canvas{

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

module.exports = Canvas;