{
    "pipeline":[{
        "name":"fork",
    },{
        "name":"mono",
        "attr":{
            "weight": [0.2126, 0.7152, 0.0722],
            "color": [1.0, 0.0, 1.0, 1.0]
        }
    },{
        "name":"swap",
    },{
        "name":"sobel",
    },{
        "name":"alpha",
        "attr":{
            "ratio": [0.5]
        }
    }]
}
