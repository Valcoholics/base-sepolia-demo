import {Color, Scene, ColorRepresentation} from "three";

const createScene = (bgColor: ColorRepresentation) => {
    const scene = new Scene();
    scene.background = new Color(0x000000);
    return scene;
};

export default createScene;
