"
I am an Athens renderer which uses SDL2.
"
Class {
	#name : #OSSDL2AthensRenderer,
	#superclass : #OSWindowAthensRenderer,
	#instVars : [
		'texture',
		'renderer',
		'pixels',
		'pitch',
		'sdlSurface',
		'textureExtent',
		'surfaceForm',
		'mutex'
	],
	#pools : [
		'SDL2Constants'
	],
	#category : #'OSWindow-SDL2-Rendering'
}

{ #category : #'instance creation' }
OSSDL2AthensRenderer class >> for: aWindowHandle [
	^ self basicNew 
		initializeWindowHandle: aWindowHandle;
		yourself
]

{ #category : #'instance creation' }
OSSDL2AthensRenderer class >> new [ 
	self error: 'Use #for:'
]

{ #category : #accessing }
OSSDL2AthensRenderer >> athensSurface [
	^ mutex critical: [super athensSurface]
]

{ #category : #private }
OSSDL2AthensRenderer >> createSDLSurfaceWithExtent: extent [
	surfaceForm ifNotNil: [ surfaceForm destroySurface ].
	"createRGBSurfaceForCairoWidth creates the surface with autoRelease."
	sdlSurface := SDL2 createRGBSurfaceForCairoWidth: extent x height: extent y.
	surfaceForm := OSSDL2ExternalForm extent: extent depth: 32 bits: sdlSurface pixels.
]

{ #category : #deleting }
OSSDL2AthensRenderer >> destroy [
	
	mutex critical: [
		(texture isNotNil and: [texture isNull not]) ifTrue: [
			texture destroy
		].
		texture := nil.

		(renderer isNotNil and: [renderer isNull not]) ifTrue: [
			renderer destroy
		].
		renderer := nil.
		sdlSurface := nil.
	].

	super destroy.
	

]

{ #category : #initialization }
OSSDL2AthensRenderer >> initialize [
	super initialize.
	mutex := Mutex new.
]

{ #category : #initialization }
OSSDL2AthensRenderer >> initializeWindowHandle: aBackendWindow [ 
	self initialize.
	self backendWindow: aBackendWindow.
	renderer := backendWindow sdl2Window createDefaultRenderer.
	self resetResources.
	
]

{ #category : #drawing }
OSSDL2AthensRenderer >> prepareForDrawing [
	mutex critical: [
		textureExtent ~= renderer outputExtent ifTrue: [ self resized ].
	].
]

{ #category : #'updating screen' }
OSSDL2AthensRenderer >> present [
	mutex critical: [
		self validate ifFalse: [ ^ self ].
		renderer
			clear;
			copy: texture;
			present
	]
]

{ #category : #private }
OSSDL2AthensRenderer >> primitiveUpdateRectangle: rectangle externalForm: externalForm [
	externalForm copy: rectangle from: surfaceForm to: rectangle origin rule: Form over
]

{ #category : #'updating resources' }
OSSDL2AthensRenderer >> resetResources [
	| extent |
	self checkSession.
	extent := renderer outputExtent.
	self createSDLSurfaceWithExtent: extent.
	athensSurface := AthensCairoSDLSurface fromSDLSurface: sdlSurface.
	texture := renderer 
		createTextureFormat: SDL_PIXELFORMAT_XRGB8888 
		access: SDL_TEXTUREACCESS_STREAMING 
		width: extent x 
		height: extent y.
	textureExtent := extent.
]

{ #category : #'updating screen' }
OSSDL2AthensRenderer >> resized [
	mutex critical: [
		self resetResources.
		super resized
	]
]

{ #category : #accessing }
OSSDL2AthensRenderer >> surface [
	^ mutex critical: [super surface]
]

{ #category : #'updating screen' }
OSSDL2AthensRenderer >> updateAll [
	mutex critical: [
		self validate ifFalse: [ ^ self ].
		texture updateTexturePixels: sdlSurface pixels pitch: sdlSurface pitch.
	]
]

{ #category : #'updating screen' }
OSSDL2AthensRenderer >> updateRectangle: aRectangle [
	| intersection pitchHolder externalForm |
	mutex critical: [
		self validate ifFalse: [ ^ self ].
		intersection := aRectangle
			intersect: (0 @ 0 corner: textureExtent)
			ifNone: [ ^ self ].
	
		pixels := ExternalAddress new.
		pitchHolder := ExternalAddress allocate: 4.
		[
			texture lockPixels: pixels pitch: pitchHolder.
			pitch := pitchHolder signedLongAt: 1.
		] ensure: [ pitchHolder free ].

		externalForm := OSSDL2ExternalForm extent: textureExtent depth: 32 bits: pixels.
		[
			self primitiveUpdateRectangle: intersection externalForm: externalForm
		] ensure: [
			texture unlock.
			externalForm destroySurface
		].
	]
]

{ #category : #'updating screen' }
OSSDL2AthensRenderer >> updateRectangles: allDamage [
	| pitchHolder externalForm intersection |
	mutex critical: [
		self validate
			ifFalse: [ ^ self ].
		
		pixels := ExternalAddress new.
		pitchHolder := ExternalAddress allocate: 4.
		[
			texture lockPixels: pixels pitch: pitchHolder.
			pitch := pitchHolder signedLongAt: 1.
		] ensure: [ pitchHolder free ].
	
		[
			externalForm := OSSDL2ExternalForm extent: textureExtent depth: 32 bits: pixels.
			allDamage do: [ :rectangle |
				intersection := rectangle
					intersect: (0 @ 0 corner: backendWindow extent)
					ifNone: [ nil ].
		
				intersection ifNotNil: [
					self primitiveUpdateRectangle: rectangle externalForm: externalForm.
				]
			].
		] ensure: [
			texture unlock.
			externalForm destroySurface
		].
	]
]

{ #category : #'updating screen' }
OSSDL2AthensRenderer >> validate [
	self checkSession.
	(texture isNil or: [ texture isNull ]) ifTrue: [ ^ false ].
	(renderer isNil or: [ renderer isNull ]) ifTrue: [ ^ false ].
	renderer outputExtent ~= textureExtent ifTrue: [ ^ false ].
	^ true
]
