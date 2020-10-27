import QtQuick 2.12
import QtQuick.Window 2.12
import QtQuick.Controls 2.0

Window {
    width: 1024
    height: 700
    visible: true
    title: qsTr("Color Balance Shader Test")

    property alias hue: hueSlider.value
    property alias brightness: brightnessSlider.value
    property alias saturation: saturationSlider.value
    property alias contrast: contrastSlider.value

    property int columnWidth: (width - 4*10)/5

    Column {
        id: grid

        anchors.fill: parent
        anchors.margins: 10
        spacing: 10

        Image {
            id: videoItem

            // Got these images from wikipedia
            property var images: ["color_bars.png", "pal_signals.png"]
            property int currentImage: 0

            width: 200
            height: 200
            anchors.horizontalCenter: parent.horizontalCenter

            source: images[currentImage]

            MouseArea {
                anchors.fill: parent
                onClicked: parent.currentImage = (parent.currentImage + 1) % parent.images.length
            }
        }

        Row {
            spacing: 10
            anchors.horizontalCenter: parent.horizontalCenter
            ShaderEffect {
                id: withClamp

                readonly property var source: videoItem

                readonly property matrix4x4 yuvaBalanceMatrix: Qt.matrix4x4(0.256816 * contrast, -0.148246,  0.439271, 0,
                                                                            0.504154 * contrast, -0.29102,  -0.367833, 0,
                                                                            0.0979137 * contrast, 0.439266, -0.071438, 0,
                                                                            0,                    0,         0,        1)
                                                                 .times(Qt.matrix4x4(1, 0,                                  0,                                  0,
                                                                                     0, saturation * Math.cos(Math.PI*hue),-saturation * Math.sin(Math.PI*hue), 0,
                                                                                     0, saturation * Math.sin(Math.PI*hue), saturation * Math.cos(Math.PI*hue), 0,
                                                                                     0, 0,                                  0,                                  1))

                readonly property vector4d yuvaBalanceConstant: Qt.vector4d(0.0625 * contrast + contrast * ((16.0 * 219.0 / 256.0 / 256.0) / (219.0 / 256.0)) + brightness - (16.0 / 256.0),
                                                                            0.5,
                                                                            0.5,
                                                                            0)


                width: 200
                height: 200

                layer.enabled: true

                fragmentShader:  "
                                  varying vec2 qt_TexCoord0;
                                  uniform sampler2D source;
                                  uniform mat4 yuvaBalanceMatrix;
                                  uniform vec4 yuvaBalanceConstant;
                                  uniform vec2 uvOffset;
                                  uniform vec2 uvScale;

                                  #define from_yuv_bt601_offset vec4(-0.0625, -0.5, -0.5, 0.0)
                                  #define from_yuv_coeff_mat mat4(1.164, 0.000, 1.596, 0.0,\
                                                                  1.164,-0.391,-0.813, 0.0,\
                                                                  1.164, 2.018, 0.000, 0.0,\
                                                                  0.0,   0.0,   0.0,   1.0)

                                  void main () {
                                      vec4 rgba = texture2D (source, qt_TexCoord0);
                                      vec4 yuva = rgba * yuvaBalanceMatrix + yuvaBalanceConstant;
                                      yuva = clamp(yuva, 0.0, 1.0);
                                      gl_FragColor = yuva * from_yuv_coeff_mat + from_yuv_bt601_offset * from_yuv_coeff_mat;
                                  }
                                  "

            }

            ShaderEffect {
                id: withoutClamp

                readonly property var source: videoItem

                readonly property matrix4x4 bt601yuvToRgbMatrix: Qt.matrix4x4(1.164, 1.164, 1.164, 0.0,
                                                                              0.000,-0.391, 2.018, 0.0,
                                                                              1.596,-0.813, 0.000, 0.0,
                                                                              0.0,   0.0,   0.0,   1.0)

                readonly property matrix4x4 bt601rgbToYuvMatrix: Qt.matrix4x4(0.256816, -0.148246,  0.439271, 0,
                                                                              0.504154, -0.29102,  -0.367833, 0,
                                                                              0.0979137, 0.439266, -0.071438, 0,
                                                                              0,         0,         0,        1)

                readonly property matrix4x4 yuvaBalanceMatrix: bt601rgbToYuvMatrix
                                                               .times(Qt.matrix4x4(contrast, 0, 0, 0,
                                                                                   0,        1, 0, 0,
                                                                                   0,        0, 1, 0,
                                                                                   0,        0, 0, 1))
                                                               .times(Qt.matrix4x4(1, 0,                                  0,                                  0,
                                                                                   0, saturation * Math.cos(Math.PI*hue),-saturation * Math.sin(Math.PI*hue), 0,
                                                                                   0, saturation * Math.sin(Math.PI*hue), saturation * Math.cos(Math.PI*hue), 0,
                                                                                   0, 0,                                  0,                                  1))
                                                               .times(bt601yuvToRgbMatrix)

                readonly property vector4d yuvaBalanceConstant: Qt.vector4d(0.0625 * contrast + contrast * ((16.0 * 219.0 / 256.0 / 256.0) / (219.0 / 256.0)) + brightness - (16.0 / 256.0),
                                                                            0.5,
                                                                            0.5,
                                                                            0)
                                                                  .times(bt601yuvToRgbMatrix)
                                                                  .plus(Qt.vector4d(-0.0625, -0.5, -0.5, 0.0)
                                                                  .times(bt601yuvToRgbMatrix))


                width: 200
                height: 200

                layer.enabled: true

                fragmentShader:  "
                                  varying vec2 qt_TexCoord0;
                                  uniform sampler2D source;
                                  uniform mat4 yuvaBalanceMatrix;
                                  uniform vec4 yuvaBalanceConstant;

                                  void main () {
                                      vec4 rgba = texture2D (source, qt_TexCoord0);
                                      gl_FragColor = rgba * yuvaBalanceMatrix + yuvaBalanceConstant;
                                  }
                                  "
            }

        }

        Row {
            spacing: 10
            anchors.horizontalCenter: parent.horizontalCenter

            Label {
                text: "Hue"
                width: columnWidth
                anchors.verticalCenter: parent.verticalCenter
            }

            Slider {
                id: hueSlider
                from: -1
                to: 1
                value: 0
                width: 3 * columnWidth
                anchors.verticalCenter: parent.verticalCenter
            }

            Label {
                text: hue.toFixed(5)
                width: columnWidth
                anchors.verticalCenter: parent.verticalCenter
            }
        }

        Row {
            spacing: 10
            anchors.horizontalCenter: parent.horizontalCenter

            Label {
                text: "Saturation"
                width: columnWidth
                anchors.verticalCenter: parent.verticalCenter
            }

            Slider {
                id: saturationSlider
                from: 0
                to: 2
                value: 1
                width: 3 * columnWidth
                anchors.verticalCenter: parent.verticalCenter
            }

            Label {
                text: saturation.toFixed(5)
                width: columnWidth
                anchors.verticalCenter: parent.verticalCenter
            }
        }

        Row {
            spacing: 10
            anchors.horizontalCenter: parent.horizontalCenter

            Label {
                text: "Brightness"
                width: columnWidth
                anchors.verticalCenter: parent.verticalCenter
            }

            Slider {
                id: brightnessSlider
                from: -1
                to: 1
                value: 0
                width: 3 * columnWidth
                anchors.verticalCenter: parent.verticalCenter
            }

            Label {
                text: brightness.toFixed(5)
                width: columnWidth
                anchors.verticalCenter: parent.verticalCenter
            }
        }

        Row {
            spacing: 10
            anchors.horizontalCenter: parent.horizontalCenter

            Label {
                text: "Contrast"
                width: columnWidth
                anchors.verticalCenter: parent.verticalCenter
            }

            Slider {
                id: contrastSlider
                from: 0
                to: 2
                value: 1
                width: 3 * columnWidth
                anchors.verticalCenter: parent.verticalCenter
            }

            Label {
                text: contrast.toFixed(5)
                width: columnWidth
                anchors.verticalCenter: parent.verticalCenter
            }
        }

        Button {
            text: "Reset"
            anchors.horizontalCenter: parent.horizontalCenter
            onClicked: {
                hue = 0
                brightness = 0
                contrast = 1
                saturation = 1
            }
        }
    }


}
