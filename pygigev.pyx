import numpy as np
cimport numpy as np

from cython cimport view
from cython.view cimport array as cvarray

from libc.stdlib cimport malloc, free

cimport decl

cdef class PyGigEV:
	cdef:
		decl.GEV_CAMERA_INFO cameras
		decl.GEV_CAMERA_HANDLE handle
		decl.GEV_BUFFER_OBJECT* image_object_ptr
		decl.UINT8[:, ::1] buffers
		decl.UINT8** buffers_ptr

	def __cinit__(self):
		self.handle = NULL

	def __init__(self):
		self.GevGetCameraList()

	def GevGetCameraList(self, int maxCameras=1000):
		cdef int numCameras
		cdef decl.GEV_STATUS exitcode = decl.GevGetCameraList(&self.cameras, maxCameras, &numCameras)
		return (self.handleExitCode(exitcode), self.cameras, numCameras)

	def GevOpenCamera(self, int gevAccessMode=4, int cameraListIndex=0):
		cdef decl.GEV_CAMERA_INFO _device = self.cameras  # what happens with multiple cameras in list??
		cdef decl.GEV_STATUS exitcode = decl.GevOpenCamera(&_device, <decl.GevAccessMode>gevAccessMode, &self.handle)
		return self.handleExitCode(exitcode)

	def GevCloseCamera(self):
		cdef decl.GEV_STATUS exitcode = decl.GevCloseCamera(&self.handle)
		free(self.buffers_ptr)
		return self.handleExitCode(exitcode)

	def GevGetCameraInterfaceOptions(self):
		cdef decl.GEV_CAMERA_OPTIONS options
		cdef decl.GEV_STATUS exitcode = decl.GevGetCameraInterfaceOptions(self.handle, &options)
		return (self.handleExitCode(exitcode), options)

	def GevSetCameraInterfaceOptions(self, options):
		cdef decl.GEV_CAMERA_OPTIONS _options = options
		cdef decl.GEV_STATUS exitcode = decl.GevSetCameraInterfaceOptions(self.handle, &_options)
		return self.handleExitCode(exitcode)

	def GevGetImageParameters(self):
		cdef decl.UINT32 width = 0
		cdef decl.UINT32 height = 0
		cdef decl.UINT32 x_offset = 0
		cdef decl.UINT32 y_offset = 0
		cdef decl.UINT32 format = 0
		cdef decl.GEV_STATUS exitcode = decl.GevGetImageParameters(self.handle, &width, &height, &x_offset, &y_offset, &format)
		return {'code': exitcode, 'width': width, 'height': height, 'x_offset': x_offset, 'y_offset': y_offset, 'pixelFormat':(format, hex(format))}

	def GevInitImageTransfer(self, int bufferCyclingMode=1, int numImgBuffers=8):
		cdef decl.GEV_STATUS exitcode
		imgParams = self.GevGetImageParameters()
		cdef decl.UINT32 size = self.GetPixelSizeInBytes(imgParams['pixelFormat'][0]) * \
								imgParams['width'] * imgParams['height']

		# create variable to hold a image buffer
		self.buffers = np.empty(shape=[numImgBuffers,size], dtype=np.uint8, order="C")

		# create helper array to get a pointers
		self.buffers_ptr = <decl.UINT8**>malloc(numImgBuffers * sizeof(decl.UINT8*))

		# loop through buffer elements to addresses to store in helper array
		if not self.buffers_ptr: raise MemoryError
		try: 
			for i in range(numImgBuffers):
				self.buffers_ptr[i] = &self.buffers[i,0]

			exitcode = decl.GevInitImageTransfer(self.handle, <decl.GevBufferCyclingMode>bufferCyclingMode, numImgBuffers, &self.buffers_ptr[0])
		except:
			pass
		#finally:
			#free(buffers_ptr)

		return self.handleExitCode(exitcode)

	def GevInitializeImageTransfer(self, int numImgBuffers=8):
		cdef decl.GEV_STATUS exitcode
		imgParams = self.GevGetImageParameters()
		cdef decl.UINT32 size = self.GetPixelSizeInBytes(imgParams['pixelFormat'][0]) * \
								imgParams['width'] * imgParams['height']

		# create variable to hold a image buffer
		self.buffers = np.empty(shape=[numImgBuffers,size], dtype=np.uint8, order="C")
		
		# create helper array to store image array pointers
		self.buffers_ptr = <decl.UINT8**>malloc(numImgBuffers * sizeof(decl.UINT8*))

		# loop through buffer elements to get addresses to store in helper array
		if not self.buffers_ptr: raise MemoryError
		try:
			for i in range(numImgBuffers):
				self.buffers_ptr[i] = &self.buffers[i,0]

			exitcode = decl.GevInitializeImageTransfer(self.handle, numImgBuffers, &self.buffers_ptr[0])
		except:
			pass
		#finally:
			#free(buffers_ptr)

		return self.handleExitCode(exitcode)

	def GevStartImageTransfer(self, int numFrames):
		cdef decl.GEV_STATUS exitcode = decl.GevStartImageTransfer(self.handle, <decl.UINT32>numFrames)
		return self.handleExitCode(exitcode)

	def GevGetImageBuffer(self):
		return np.asarray(self.buffers[0,:])
		#cdef void** buffer_ptr
		#cdef decl.GEV_STATUS exitcode
		#exitcode = decl.GevGetImageBuffer(self.handle, buffer_ptr)

		##cdef view.array buffer_view = <np.uint8[:10]> buffer_ptr
		#cdef view.array buffer_view = view.array(shape=(100), itemsize=sizeof(decl.UINT8), format="i", mode="c", allocate_buffer=False)
		#buffer_view.data = <char *> buffer_ptr

		#return exitcode

	# def GevWaitForNextImageBuffer(self, int timeout):
	# 	cdef void** buffer_ptr = NULL
	# 	cdef decl.GEV_STATUS exitcode
	# 	exitcode = decl.GevWaitForNextImageBuffer(self.handle, buffer_ptr, <decl.UINT32>timeout)
	# 	return exitcode

	# not working?
	def GevStopImageTransfer(self):
		cdef decl.GEV_STATUS exitcode = decl.GevStopImageTransfer(self.handle)
		return self.handleExitCode(exitcode)

	# not working?
	def GevAbortImageTransfer(self):
		cdef decl.GEV_STATUS exitcode = decl.GevAbortImageTransfer(self.handle)
		return self.handleExitCode(exitcode)
	
	# havn't tested since previous 2 aren't working
	def GevReleaseImage(self):
		cdef decl.GEV_STATUS exitcode = decl.GevReleaseImage(&self.handle, self.image_object_ptr)
		return self.handleExitCode(exitcode)

	@staticmethod
	def GevApiInitialize():
		return decl.GevApiInitialize()
	
	@staticmethod
	def GevApiUninitialize():
		return decl.GevApiUninitialize()

	@staticmethod
	def GevGetLibraryConfigOptions():
		cdef decl.GEVLIB_CONFIG_OPTIONS options
		cdef decl.GEV_STATUS exitcode
		exitcode = decl.GevGetLibraryConfigOptions(&options)
		return (exitcode, options)

	@staticmethod
	def GevSetLibraryConfigOptions(object options):
		cdef decl.GEVLIB_CONFIG_OPTIONS _options = options
		cdef decl.GEV_STATUS exitcode
		exitcode = decl.GevGetLibraryConfigOptions(&_options)
		return exitcode

	@staticmethod
	def GevDeviceCount():
		return decl.GevDeviceCount()

	@staticmethod 
	def GetPixelSizeInBytes(int pixelFormat):
		return decl.GetPixelSizeInBytes(pixelFormat)

	@staticmethod 
	def GevGetPixelDepthInBits(int pixelFormat):
		return decl.GevGetPixelDepthInBits(pixelFormat)

	@staticmethod
	def handleExitCode(exitcode):
		if exitcode is not 0:
			return "Method returned code " + str(exitcode) + ", please check your camera's manual."
		else: return "OK"

