import React, { useState, useEffect } from 'react';
import { View, Text, StyleSheet, TouchableOpacity, ScrollView, Alert, Dimensions } from 'react-native';
import { CameraView, useCameraPermissions } from 'expo-camera';
import * as ImageManipulator from 'expo-image-manipulator';

const { width } = Dimensions.get('window');

export default function App() {
  const [permission, requestPermission] = useCameraPermissions();
  const [cameraRef, setCameraRef] = useState(null);
  const [isProcessing, setIsProcessing] = useState(false);
  const [capturedImage, setCapturedImage] = useState(null);
  const [ocrResults, setOcrResults] = useState({
    city: 'Not found',
    date: 'Not found',
    ticketNumber: 'Not found',
    rawText: ''
  });

  const cameraStyle = {
    width: width - 32,
    height: 300,
  };

  useEffect(() => {
    if (permission === null) {
      requestPermission();
    }
  }, [permission, requestPermission]);

  const vietnameseCityMappings = {
    'Ho Chi Minh': ['HO CHI MINH', 'HÓ CHÍ MINH', 'TP HCM', 'TP.HCM', 'TPHCM', 'SAI GON', 'SAIGON'],
    'Hanoi': ['HANOI', 'HÀ NỘI', 'HA NOI'],
    'Danang': ['DANANG', 'ĐÀ NẴNG', 'DA NANG'],
    'Can Tho': ['CAN THO', 'CẦN THƠ'],
    'Hai Phong': ['HAI PHONG', 'HẢI PHÒNG'],
    'An Giang': ['AN GIANG'],
    'Bac Lieu': ['BAC LIEU', 'BẠC LIÊU'],
    'Ben Tre': ['BEN TRE', 'BẾN TRE'],
    'Binh Duong': ['BINH DUONG', 'BÌNH DƯƠNG'],
    'Binh Phuoc': ['BINH PHUOC', 'BÌNH PHƯỚC'],
    'Binh Thuan': ['BINH THUAN', 'BÌNH THUẬN'],
    'Ca Mau': ['CA MAU', 'CÀ MAU'],
    'Dalat': ['DALAT', 'ĐÀ LẠT', 'DA LAT'],
    'Dong Nai': ['DONG NAI', 'ĐỒNG NAI'],
    'Dong Thap': ['DONG THAP', 'ĐỒNG THÁP'],
    'Hau Giang': ['HAU GIANG', 'HẬU GIANG'],
    'Kien Giang': ['KIEN GIANG', 'KIÊN GIANG'],
    'Long An': ['LONG AN'],
    'Soc Trang': ['SOC TRANG', 'SÓC TRĂNG'],
    'Tay Ninh': ['TAY NINH', 'TÂY NINH'],
    'Tien Giang': ['TIEN GIANG', 'TIỀN GIANG', 'TIÊN GIANG'],
    'Tra Vinh': ['TRA VINH', 'TRÀ VINH'],
    'Vinh Long': ['VINH LONG', 'VĨNH LONG'],
    'Vung Tau': ['VUNG TAU', 'VŨNG TÀU'],
    'Bac Ninh': ['BAC NINH', 'BẮC NINH'],
    'Nam Dinh': ['NAM DINH', 'NAM ĐỊNH'],
    'Quang Ninh': ['QUANG NINH', 'QUẢNG NINH'],
    'Thai Binh': ['THAI BINH', 'THÁI BÌNH'],
    'Binh Dinh': ['BINH DINH', 'BÌNH ĐỊNH'],
    'Dak Lak': ['DAK LAK', 'ĐẮK LẮK'],
    'Dak Nong': ['DAK NONG', 'ĐẮK NÔNG'],
    'Gia Lai': ['GIA LAI'],
    'Khanh Hoa': ['KHANH HOA', 'KHÁNH HÒA'],
    'Kon Tum': ['KON TUM'],
    'Ninh Thuan': ['NINH THUAN', 'NINH THUẬN'],
    'Phu Yen': ['PHU YEN', 'PHÚ YÊN'],
    'Quang Binh': ['QUANG BINH', 'QUẢNG BÌNH'],
    'Quang Nam': ['QUANG NAM', 'QUẢNG NAM'],
    'Quang Ngai': ['QUANG NGAI', 'QUẢNG NGÃI'],
    'Quang Tri': ['QUANG TRI', 'QUẢNG TRỊ'],
    'Hue': ['HUE', 'HUẾ'],
  };

  const parseTicketInfo = (text) => {
    const upperText = text.toUpperCase();
    let city = 'Not found';
    let date = 'Not found';
    let ticketNumber = 'Not found';

    // Extract city
    for (const [cityName, variations] of Object.entries(vietnameseCityMappings)) {
      for (const variation of variations) {
        if (upperText.includes(variation)) {
          city = cityName;
          break;
        }
      }
      if (city !== 'Not found') break;
    }

    // Extract date (DD-MM-YYYY or D-M-YYYY)
    const dateRegex = /(\d{1,2})[-\/](\d{1,2})[-\/](\d{4})/;
    const dateMatch = text.match(dateRegex);
    if (dateMatch) {
      const day = dateMatch[1];
      const month = dateMatch[2];
      const year = dateMatch[3];
      date = `${day}-${month}-${year}`;
    }

    // Extract 6-digit ticket number
    const numberRegex = /\b(\d{6})\b/g;
    const numberMatches = text.match(numberRegex);
    if (numberMatches) {
      for (const number of numberMatches) {
        if (!number.startsWith('000') && !number.startsWith('111')) {
          ticketNumber = number;
          break;
        }
      }
    }

    return { city, date, ticketNumber, rawText: text };
  };

  const simulateOCR = async (imageUri) => {
    // Simulate OCR processing for now
    const mockOcrText = `XO Số KIẾN THIẾT HÓ CHÍ MINH
    RIEN THIE,
    SO
    MTV XO
    o
    e
    OBD CO.
    Soạn tin: XSBD gửi đến 997 177
    59880&
    18-7-20a
    Mở ngày 18-7-2025
    Gii đặc biệt 2 tị đồng
    .0007
    HH
    E
    EY
    5.9,8806
    00L€:NO
    485201
    19-7-2025`;
    
    return mockOcrText;
  };

  const takePictureAndProcess = async () => {
    if (!cameraRef) {
      Alert.alert('Error', 'Camera not ready');
      return;
    }

    setIsProcessing(true);
    try {
      console.log('Taking picture...');
      
      // Take picture
      const photo = await cameraRef.takePictureAsync({
        quality: 0.8,
        base64: false,
      });

      console.log('Photo taken:', photo.uri);
      setCapturedImage(photo.uri);

      // Rotate image 270 degrees
      const rotatedImage = await ImageManipulator.manipulateAsync(
        photo.uri,
        [{ rotate: 270 }],
        { compress: 0.8, format: ImageManipulator.SaveFormat.JPEG }
      );

      console.log('Image rotated:', rotatedImage.uri);

      // Simulate OCR for now (replace with real OCR later)
      const text = await simulateOCR(rotatedImage.uri);
      console.log('OCR Result:', text);

      // Parse results
      const results = parseTicketInfo(text);
      setOcrResults(results);

      console.log('Parsed Results:', results);

    } catch (error) {
      console.error('Error processing image:', error);
      Alert.alert('Error', 'Failed to process image: ' + error.message);
    } finally {
      setIsProcessing(false);
    }
  };

  const renderResultRow = (label, value) => {
    const isCorrect = value !== 'Not found';
    return (
      <View style={styles.resultRow} key={label}>
        <Text style={styles.resultLabel}>{label}</Text>
        <Text style={[styles.resultValue, { color: isCorrect ? '#4CAF50' : '#F44336' }]}>
          {value}
        </Text>
        <Text style={styles.resultIcon}>{isCorrect ? '✓' : '✗'}</Text>
      </View>
    );
  };

  if (permission === null) {
    return (
      <View style={styles.container}>
        <Text style={styles.message}>Requesting camera permission...</Text>
      </View>
    );
  }

  if (permission === false) {
    return (
      <View style={styles.container}>
        <Text style={styles.message}>Camera permission is required</Text>
        <TouchableOpacity style={styles.button} onPress={requestPermission}>
          <Text style={styles.buttonText}>Grant Permission</Text>
        </TouchableOpacity>
      </View>
    );
  }

  return (
    <ScrollView style={styles.container}>
      <View style={styles.content}>
        <Text style={styles.title}>Vietnamese Lottery OCR</Text>
        
        {/* Camera Preview */}
        <View style={styles.cameraContainer}>
          <CameraView
            style={cameraStyle}
            facing="back"
            ref={setCameraRef}
          />
        </View>

        {/* Take Picture Button */}
        <TouchableOpacity
          style={[styles.button, isProcessing && styles.buttonDisabled]}
          onPress={takePictureAndProcess}
          disabled={isProcessing}
        >
          <Text style={styles.buttonText}>
            {isProcessing ? 'Processing...' : 'Take Picture'}
          </Text>
        </TouchableOpacity>

        {/* Previous Results */}
        <View style={styles.section}>
          <Text style={styles.sectionTitle}>PREVIOUS SUCCESSFUL RESULTS:</Text>
          <Text style={styles.previousResult}>IMG_2308.jpg - City: Tien Giang, Date: 20-07-2025, Ticket: 074380 ✓</Text>
          <Text style={styles.previousResult}>IMG_2309.jpg - City: Binh Duong, Date: 18-7-2025, Ticket: 598806 ✓</Text>
          <Text style={styles.previousResult}>IMG_2310.jpg - City: Ho Chi Minh, Date: 19-7-2025, Ticket: 485201 ✓</Text>
        </View>

        {/* Current Results */}
        <View style={styles.section}>
          <Text style={styles.sectionTitle}>CURRENT RESULTS:</Text>
          
          {isProcessing ? (
            <View style={styles.processingContainer}>
              <Text style={styles.processingText}>Processing image with OCR...</Text>
              <Text style={styles.processingSteps}>
                1. Rotating image 270°{'\n'}
                2. Running OCR (simulated){'\n'}
                3. Extracting City, Date, and Ticket Number
              </Text>
            </View>
          ) : (
            <View>
              {renderResultRow('City:', ocrResults.city)}
              {renderResultRow('Date:', ocrResults.date)}
              {renderResultRow('Ticket Number:', ocrResults.ticketNumber)}
              
              {ocrResults.rawText ? (
                <View style={styles.rawTextContainer}>
                  <Text style={styles.rawTextTitle}>RAW OCR TEXT:</Text>
                  <ScrollView style={styles.rawTextScroll} nestedScrollEnabled={true}>
                    <Text style={styles.rawText}>{ocrResults.rawText}</Text>
                  </ScrollView>
                </View>
              ) : (
                <View style={styles.instructionContainer}>
                  <Text style={styles.instructionText}>
                    Take a picture to extract lottery ticket information{'\n\n'}
                    The app will automatically:{'\n'}
                    1. Rotate the image 270°{'\n'}
                    2. Run OCR (currently simulated){'\n'}
                    3. Extract City, Date, and Ticket Number
                  </Text>
                </View>
              )}
            </View>
          )}
        </View>

        {capturedImage && (
          <View style={styles.section}>
            <Text style={styles.sectionTitle}>CAPTURED IMAGE:</Text>
            <Text style={styles.capturedImagePath}>{capturedImage}</Text>
          </View>
        )}
      </View>
    </ScrollView>
  );
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
    backgroundColor: '#fff',
  },
  content: {
    padding: 16,
    paddingTop: 50,
  },
  title: {
    fontSize: 24,
    fontWeight: 'bold',
    textAlign: 'center',
    marginBottom: 20,
    color: '#333',
  },
  cameraContainer: {
    alignItems: 'center',
    marginBottom: 20,
    borderRadius: 8,
    overflow: 'hidden',
    borderWidth: 2,
    borderColor: '#ddd',
  },
  button: {
    backgroundColor: '#2196F3',
    padding: 16,
    borderRadius: 8,
    alignItems: 'center',
    marginBottom: 20,
  },
  buttonDisabled: {
    backgroundColor: '#ccc',
  },
  buttonText: {
    color: '#fff',
    fontSize: 18,
    fontWeight: 'bold',
  },
  section: {
    marginBottom: 20,
  },
  sectionTitle: {
    fontSize: 16,
    fontWeight: 'bold',
    marginBottom: 10,
    color: '#333',
  },
  previousResult: {
    fontSize: 14,
    color: '#4CAF50',
    marginBottom: 5,
  },
  resultRow: {
    flexDirection: 'row',
    alignItems: 'center',
    paddingVertical: 8,
  },
  resultLabel: {
    fontSize: 16,
    fontWeight: 'bold',
    width: 120,
    color: '#333',
  },
  resultValue: {
    fontSize: 16,
    fontWeight: 'bold',
    flex: 1,
  },
  resultIcon: {
    fontSize: 18,
    width: 30,
    textAlign: 'center',
  },
  processingContainer: {
    alignItems: 'center',
    padding: 20,
  },
  processingText: {
    fontSize: 16,
    fontWeight: 'bold',
    marginBottom: 10,
    color: '#333',
  },
  processingSteps: {
    fontSize: 14,
    color: '#666',
    textAlign: 'center',
    lineHeight: 20,
  },
  rawTextContainer: {
    marginTop: 20,
  },
  rawTextTitle: {
    fontSize: 16,
    fontWeight: 'bold',
    marginBottom: 10,
    color: '#333',
  },
  rawTextScroll: {
    maxHeight: 150,
    borderWidth: 1,
    borderColor: '#ddd',
    borderRadius: 8,
    padding: 12,
    backgroundColor: '#f9f9f9',
  },
  rawText: {
    fontSize: 12,
    fontFamily: 'monospace',
    color: '#333',
  },
  instructionContainer: {
    alignItems: 'center',
    padding: 20,
  },
  instructionText: {
    fontSize: 16,
    color: '#666',
    textAlign: 'center',
    lineHeight: 22,
  },
  message: {
    textAlign: 'center',
    fontSize: 18,
    color: '#333',
  },
  capturedImagePath: {
    fontSize: 12,
    color: '#666',
    fontFamily: 'monospace',
  },
});