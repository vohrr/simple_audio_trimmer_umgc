package com.raynear.audio_trimmer

import android.media.*
import android.os.Build
import androidx.annotation.NonNull
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.*
import java.nio.ByteBuffer
import java.nio.ByteOrder
import kotlin.math.min

class AudioTrimmerPlugin : FlutterPlugin, MethodChannel.MethodCallHandler {
    private lateinit var channel: MethodChannel

    override fun onAttachedToEngine(@NonNull flutterPluginBinding: FlutterPlugin.FlutterPluginBinding) {
        channel = MethodChannel(flutterPluginBinding.binaryMessenger, "simple_audio_trimmer")
        channel.setMethodCallHandler(this)
    }

    override fun onMethodCall(@NonNull call: MethodCall, @NonNull result: MethodChannel.Result) {
        if (call.method == "trim") {
            val inputPath = call.argument<String>("inputPath")!!
            val outputPath = call.argument<String>("outputPath")!!
            val start = call.argument<Double>("start")!!
            val end = call.argument<Double>("end")!!

            val startUs = start.toLong() * 1000000
            val endUs = end.toLong() * 1000000

            val success = when {
                outputPath.toLowerCase().endsWith(".wav") -> trimToWav(inputPath, outputPath, startUs, endUs)
                else -> trimToMp4Container(inputPath, outputPath, startUs, endUs)
            }

            if (success) result.success(outputPath)
            else result.error("TRIM_FAILED", "Failed to trim audio", null)
        } else {
            result.notImplemented()
        }
    }

    override fun onDetachedFromEngine(@NonNull binding: FlutterPlugin.FlutterPluginBinding) {
        channel.setMethodCallHandler(null)
    }

    private fun trimToMp4Container(inputPath: String, outputPath: String, startUs: Long, endUs: Long): Boolean {
        try {
            val extractor = MediaExtractor()
            extractor.setDataSource(inputPath)

            val trackCount = extractor.trackCount
            var audioTrackIndex = -1

            for (i in 0 until trackCount) {
                val format = extractor.getTrackFormat(i)
                val mime = format.getString(MediaFormat.KEY_MIME)
                if (mime?.startsWith("audio/") == true) {
                    audioTrackIndex = i
                    break
                }
            }

            if (audioTrackIndex == -1) return false

            extractor.selectTrack(audioTrackIndex)
            val format = extractor.getTrackFormat(audioTrackIndex)
            
            val muxer = MediaMuxer(outputPath, MediaMuxer.OutputFormat.MUXER_OUTPUT_MPEG_4)
            val dstTrackIndex = muxer.addTrack(format)

            muxer.start()
            val bufferSize = 1024 * 1024
            val buffer = ByteBuffer.allocate(bufferSize)
            val bufferInfo = MediaCodec.BufferInfo()

            extractor.seekTo(startUs, MediaExtractor.SEEK_TO_PREVIOUS_SYNC)

            while (true) {
                bufferInfo.offset = 0
                bufferInfo.size = extractor.readSampleData(buffer, 0)
                if (bufferInfo.size < 0) break

                val sampleTime = extractor.sampleTime
                if (sampleTime > endUs) break

                bufferInfo.presentationTimeUs = sampleTime
                bufferInfo.flags = extractor.sampleFlags
                muxer.writeSampleData(dstTrackIndex, buffer, bufferInfo)
                extractor.advance()
            }

            muxer.stop()
            muxer.release()
            extractor.release()

            return true
        } catch (e: Exception) {
            e.printStackTrace()
            return false
        }
    }

    private fun trimToWav(inputPath: String, outputPath: String, startUs: Long, endUs: Long): Boolean {
        var extractor: MediaExtractor? = null
        var outputStream: FileOutputStream? = null
        var tempPcmFile: File? = null
        
        try {
            // 1. 오디오 트랙 추출
            extractor = MediaExtractor()
            extractor.setDataSource(inputPath)
            
            val audioTrackIndex = findAudioTrack(extractor)
            if (audioTrackIndex < 0) return false
            
            extractor.selectTrack(audioTrackIndex)
            val format = extractor.getTrackFormat(audioTrackIndex)
            
            // 오디오 파라미터 추출
            val sampleRate = format.getInteger(MediaFormat.KEY_SAMPLE_RATE)
            val channelCount = format.getInteger(MediaFormat.KEY_CHANNEL_COUNT)
            val mime = format.getString(MediaFormat.KEY_MIME)
            
            // PCM 임시 파일 생성
            tempPcmFile = File.createTempFile("temp_pcm", null)
            var totalBytesRead = 0L
            
            // 디코더 설정
            val decoder = if (mime != null) {
                val decoder = MediaCodec.createDecoderByType(mime)
                decoder.configure(format, null, null, 0)
                decoder.start()
                decoder
            } else {
                null
            }
            
            if (decoder != null) {
                // 디코더 사용하여 PCM 데이터 추출
                totalBytesRead = decodeToPcm(extractor, decoder, tempPcmFile, startUs, endUs)
                decoder.stop()
                decoder.release()
            } else {
                if (mime?.contains("pcm") == true) {
                    extractor.seekTo(startUs, MediaExtractor.SEEK_TO_PREVIOUS_SYNC)
                    val buffer = ByteBuffer.allocate(1024 * 256)
                    val fileOutputStream = FileOutputStream(tempPcmFile)
                    
                    while (true) {
                        val sampleSize = extractor.readSampleData(buffer, 0)
                        if (sampleSize < 0) break
                        
                        val sampleTime = extractor.sampleTime
                        if (sampleTime > endUs) break
                        
                        fileOutputStream.write(buffer.array(), 0, sampleSize)
                        totalBytesRead += sampleSize
                        buffer.clear()
                        extractor.advance()
                    }
                    
                    fileOutputStream.close()
                } else {
                    extractor.release()
                    return false
                }
            }
            
            // 2. PCM 데이터를 WAV로 변환
            val pcmToWav = convertPcmToWav(tempPcmFile, File(outputPath), sampleRate, channelCount, 16)
            
            extractor.release()
            tempPcmFile.delete()
            
            return pcmToWav
        } catch (e: Exception) {
            e.printStackTrace()
            return false
        } finally {
            extractor?.release()
            outputStream?.close()
            tempPcmFile?.delete()
        }
    }
    
    private fun findAudioTrack(extractor: MediaExtractor): Int {
        for (i in 0 until extractor.trackCount) {
            val format = extractor.getTrackFormat(i)
            val mime = format.getString(MediaFormat.KEY_MIME)
            if (mime?.startsWith("audio/") == true) {
                return i
            }
        }
        return -1
    }
    
    private fun decodeToPcm(extractor: MediaExtractor, decoder: MediaCodec, outputFile: File, startUs: Long, endUs: Long): Long {
        extractor.seekTo(startUs, MediaExtractor.SEEK_TO_PREVIOUS_SYNC)
        
        val bufferInfo = MediaCodec.BufferInfo()
        val timeout = 10000L
        var outputDone = false
        var inputDone = false
        var totalBytesWritten = 0L
        
        val outputStream = FileOutputStream(outputFile)
        
        while (!outputDone) {
            // 입력 처리
            if (!inputDone) {
                val inputBufferIndex = decoder.dequeueInputBuffer(timeout)
                if (inputBufferIndex >= 0) {
                    val inputBuffer = decoder.getInputBuffer(inputBufferIndex)
                    val sampleSize = extractor.readSampleData(inputBuffer!!, 0)
                    
                    if (sampleSize < 0) {
                        decoder.queueInputBuffer(inputBufferIndex, 0, 0, 0, MediaCodec.BUFFER_FLAG_END_OF_STREAM)
                        inputDone = true
                    } else {
                        val sampleTime = extractor.sampleTime
                        if (sampleTime > endUs) {
                            decoder.queueInputBuffer(inputBufferIndex, 0, 0, 0, MediaCodec.BUFFER_FLAG_END_OF_STREAM)
                            inputDone = true
                        } else {
                            decoder.queueInputBuffer(inputBufferIndex, 0, sampleSize, sampleTime, 0)
                            extractor.advance()
                        }
                    }
                }
            }
            
            // 출력 처리
            val outputBufferIndex = decoder.dequeueOutputBuffer(bufferInfo, timeout)
            if (outputBufferIndex >= 0) {
                val outputBuffer = decoder.getOutputBuffer(outputBufferIndex)
                
                if (outputBuffer != null && bufferInfo.size > 0) {
                    val chunk = ByteArray(bufferInfo.size)
                    outputBuffer.position(bufferInfo.offset)
                    outputBuffer.get(chunk)
                    outputStream.write(chunk)
                    totalBytesWritten += chunk.size
                }
                
                decoder.releaseOutputBuffer(outputBufferIndex, false)
                
                if ((bufferInfo.flags and MediaCodec.BUFFER_FLAG_END_OF_STREAM) != 0) {
                    outputDone = true
                }
            }
        }
        
        outputStream.close()
        return totalBytesWritten
    }
    
    private fun convertPcmToWav(inputFile: File, outputFile: File, sampleRate: Int, channels: Int, bitsPerSample: Int): Boolean {
        try {
            val inputSize = inputFile.length().toInt()
            
            val fileInputStream = FileInputStream(inputFile)
            val fileOutputStream = FileOutputStream(outputFile)
            
            // WAV 헤더 작성
            writeWavHeader(fileOutputStream, inputSize, sampleRate, channels, bitsPerSample)
            
            // PCM 데이터 복사
            val buffer = ByteArray(1024)
            var bytesRead: Int
            while (fileInputStream.read(buffer).also { bytesRead = it } != -1) {
                fileOutputStream.write(buffer, 0, bytesRead)
            }
            
            fileInputStream.close()
            fileOutputStream.close()
            
            return true
        } catch (e: Exception) {
            e.printStackTrace()
            return false
        }
    }
    
    private fun writeWavHeader(outputStream: FileOutputStream, audioSize: Int, sampleRate: Int, channels: Int, bitsPerSample: Int) {
        val byteRate = sampleRate * channels * bitsPerSample / 8
        val blockAlign = channels * bitsPerSample / 8
        val totalDataLen = audioSize + 36
        
        val header = ByteBuffer.allocate(44).apply {
            order(ByteOrder.LITTLE_ENDIAN)
            
            // RIFF 청크
            put("RIFF".toByteArray())
            putInt(totalDataLen)
            put("WAVE".toByteArray())
            
            // fmt 청크
            put("fmt ".toByteArray())
            putInt(16) // fmt 청크 크기
            putShort(1.toShort()) // PCM = 1
            putShort(channels.toShort())
            putInt(sampleRate)
            putInt(byteRate)
            putShort(blockAlign.toShort())
            putShort(bitsPerSample.toShort())
            
            // data 청크
            put("data".toByteArray())
            putInt(audioSize)
        }.array()
        
        outputStream.write(header)
    }
}