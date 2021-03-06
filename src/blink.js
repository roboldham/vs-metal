{
    "variables":{
        "green":[0.0, 1.0, 0.0, 1.0],
        "red":[1.0, 0.0, 0.0, 1.0],
    },
    "dynamics":{
        "myratio":{
            "type":"sin",
            "range":[0.0, 1.0],
            "interval":0.5
        }
    },
    "pipeline":[{
        "name":"discard"
    },{
        "name":"colors",
        "attr":{
            "color1": "green",
            "color2": "red",
            "ratio": "myratio",
        }
    }]
}
