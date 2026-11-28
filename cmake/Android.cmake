# Packages the game's libmain.so as an APK signed with the debug key, without Gradle: javac and d8 turn SDL's Java into classes.dex, aapt2 links the manifest, icon and assets, jar adds the dex and the library uncompressed, zipalign aligns the library to 16 KB pages and apksigner signs. ANDROID, which every Android branch keys off, is set by the NDK's toolchain file:
#
#   cmake -S . -B build/android \
#       -DCMAKE_TOOLCHAIN_FILE=<ndk>/build/cmake/android.toolchain.cmake \
#       -DANDROID_ABI=arm64-v8a -DANDROID_PLATFORM=android-24 \
#       -DFRIED_ANDROID_SDK=<sdk> -DFRIED_JAVA_HOME=<jdk>

set(FRIED_ANDROID_SDK "$ENV{ANDROID_HOME}" CACHE PATH "An Android SDK holding platforms/android-35 and build-tools/35.0.1")
set(FRIED_JAVA_HOME "$ENV{JAVA_HOME}" CACHE PATH "A JDK, whose java, javac, jar and keytool the APK is built with")
set(FRIED_ANDROID_KEYSTORE "$ENV{HOME}/.android/debug.keystore" CACHE FILEPATH "The keystore the APK is signed with, Android's debug key unless set")

set(FRIED_ANDROID_TARGET_API 35)
set(FRIED_ANDROID_BUILD_TOOLS 35.0.1)
# ANDROID_PLATFORM names the oldest Android the game runs on, as android-<level>.
string(REGEX REPLACE "^android-" "" FRIED_ANDROID_MIN_API "${ANDROID_PLATFORM}")
if(NOT FRIED_ANDROID_MIN_API MATCHES "^[0-9]+$")
    message(FATAL_ERROR "ANDROID_PLATFORM is \"${ANDROID_PLATFORM}\", which is not android-<level>, such as android-24.")
endif()

if(FRIED_SYSTEM_SDL2)
    message(FATAL_ERROR "An Android build links the SDL2 it builds itself, so FRIED_SYSTEM_SDL2 has to be OFF.")
endif()

set(_fried_android_jar "${FRIED_ANDROID_SDK}/platforms/android-${FRIED_ANDROID_TARGET_API}/android.jar")
set(_fried_android_build_tools "${FRIED_ANDROID_SDK}/build-tools/${FRIED_ANDROID_BUILD_TOOLS}")
if(NOT EXISTS "${_fried_android_jar}")
    message(FATAL_ERROR "There is no ${_fried_android_jar}. Point FRIED_ANDROID_SDK (or ANDROID_HOME) at an Android SDK with platforms/android-${FRIED_ANDROID_TARGET_API} in it.")
endif()
if(NOT EXISTS "${_fried_android_build_tools}/aapt2")
    message(FATAL_ERROR "There is no aapt2 in ${_fried_android_build_tools}. Point FRIED_ANDROID_SDK (or ANDROID_HOME) at an Android SDK with build-tools/${FRIED_ANDROID_BUILD_TOOLS} in it.")
endif()

foreach(_tool java javac jar keytool)
    string(TOUPPER ${_tool} _upper)
    find_program(FRIED_${_upper} ${_tool} HINTS "${FRIED_JAVA_HOME}/bin" NO_CMAKE_FIND_ROOT_PATH)
    if(NOT FRIED_${_upper})
        message(FATAL_ERROR "There is no ${_tool} to build the APK with. Point FRIED_JAVA_HOME (or JAVA_HOME) at a JDK.")
    endif()
endforeach()

# Android's own tools make this key the first time they need it, with these same passwords.
if(NOT EXISTS "${FRIED_ANDROID_KEYSTORE}")
    get_filename_component(_fried_keystore_dir "${FRIED_ANDROID_KEYSTORE}" DIRECTORY)
    file(MAKE_DIRECTORY "${_fried_keystore_dir}")
    execute_process(
        COMMAND "${FRIED_KEYTOOL}" -genkeypair -keystore "${FRIED_ANDROID_KEYSTORE}"
            -storepass android -alias androiddebugkey -keypass android
            -keyalg RSA -keysize 2048 -validity 10000 -dname "CN=Android Debug,O=Android,C=US"
        RESULT_VARIABLE _fried_keytool_result
    )
    if(NOT _fried_keytool_result EQUAL 0)
        message(FATAL_ERROR "The debug key could not be made at ${FRIED_ANDROID_KEYSTORE}.")
    endif()
endif()

# fried_read_android_package(<json> <organization> <name> <out>)
#
# "android.package", or com.<organization>.<name> lowercased with everything but letters, digits and underscores taken out. FriedCore's android::defaultPackage() makes the same name, so the editor shows what the build uses.
function(fried_read_android_package json organization name out)
    string(JSON _package ERROR_VARIABLE _error GET "${json}" platforms android package)
    if(_error OR _package STREQUAL "")
        set(_parts "")
        foreach(_text com "${organization}" "${name}")
            string(TOLOWER "${_text}" _part)
            string(REGEX REPLACE "[^a-z0-9_]" "" _part "${_part}")
            if(_part MATCHES "^[0-9_]")
                set(_part "x${_part}")
            endif()
            if(NOT _part STREQUAL "")
                list(APPEND _parts ${_part})
            endif()
        endforeach()
        list(LENGTH _parts _count)
        if(_count LESS 2)
            list(APPEND _parts game)
        endif()
        list(JOIN _parts "." _package)
    endif()
    if(NOT _package MATCHES "^[a-zA-Z][a-zA-Z0-9_]*(\\.[a-zA-Z][a-zA-Z0-9_]*)+$")
        message(FATAL_ERROR "project.fried gives android.package \"${_package}\", which Android refuses: it takes two or more parts joined by dots, each starting with a letter and holding only letters, digits and underscores, such as com.example.mygame.")
    endif()
    set(${out} "${_package}" PARENT_SCOPE)
endfunction()

# fried_read_android_orientation(<json> <out_manifest> <out_sdl>)
#
# "android.orientation", landscape unless it says portrait. Either way the phone may be turned around.
function(fried_read_android_orientation json out_manifest out_sdl)
    string(JSON _orientation ERROR_VARIABLE _error GET "${json}" platforms android orientation)
    if(_error OR _orientation STREQUAL "")
        set(_orientation landscape)
    endif()
    if(_orientation STREQUAL "landscape")
        set(${out_manifest} sensorLandscape PARENT_SCOPE)
        set(${out_sdl} "LandscapeLeft LandscapeRight" PARENT_SCOPE)
    elseif(_orientation STREQUAL "portrait")
        set(${out_manifest} sensorPortrait PARENT_SCOPE)
        set(${out_sdl} "Portrait PortraitUpsideDown" PARENT_SCOPE)
    else()
        message(FATAL_ERROR "project.fried gives android.orientation \"${_orientation}\", which is not one of: landscape, portrait.")
    endif()
endfunction()

# fried_add_android_apk(<target> NAME PACKAGE VERSION VERSION_CODE ORIENTATION ICON ENGINE_ASSETS GAME_ASSETS)
#
# The two asset roots go into the APK's assets/ as engine/ and game/, which SDL reads by those relative paths.
function(fried_add_android_apk target_name)
    cmake_parse_arguments(APK "" "NAME;PACKAGE;VERSION;VERSION_CODE;ORIENTATION;ICON;ENGINE_ASSETS;GAME_ASSETS" "" ${ARGN})

    set(_work "${CMAKE_CURRENT_BINARY_DIR}/${target_name}_apk")
    set(_tools "${_fried_android_build_tools}")
    set(_apk "${CMAKE_CURRENT_BINARY_DIR}/${target_name}.apk")

    file(GLOB_RECURSE _java_sources CONFIGURE_DEPENDS
        "${FRIED_SDL2_PREFIX}/share/sdl2-android-java/*.java"
        "${CMAKE_CURRENT_FUNCTION_LIST_DIR}/android/java/*.java"
    )

    add_custom_command(OUTPUT "${_work}/dex/classes.dex"
        COMMAND ${CMAKE_COMMAND} -E rm -rf "${_work}/classes" "${_work}/dex"
        COMMAND ${CMAKE_COMMAND} -E make_directory "${_work}/classes" "${_work}/dex"
        COMMAND "${FRIED_JAVAC}" --release 11 -nowarn -classpath "${_fried_android_jar}" -d "${_work}/classes" ${_java_sources}
        COMMAND "${FRIED_JAR}" --create --file "${_work}/classes.jar" -C "${_work}/classes" .
        COMMAND "${FRIED_JAVA}" -cp "${_tools}/lib/d8.jar" com.android.tools.r8.D8
            --release --min-api ${FRIED_ANDROID_MIN_API} --lib "${_fried_android_jar}"
            --output "${_work}/dex" "${_work}/classes.jar"
        DEPENDS ${_java_sources}
        COMMENT "Compiling SDL's Java into classes.dex"
        VERBATIM
    )

    # The manifest is text, so the name is escaped for XML.
    set(APK_LABEL "${APK_NAME}")
    string(REPLACE "&" "&amp;" APK_LABEL "${APK_LABEL}")
    string(REPLACE "<" "&lt;" APK_LABEL "${APK_LABEL}")
    string(REPLACE "\"" "&quot;" APK_LABEL "${APK_LABEL}")
    set(APK_ICON_ATTRIBUTE "")
    set(_icon_flat "")
    if(EXISTS "${APK_ICON}")
        set(APK_ICON_ATTRIBUTE "android:icon=\"@mipmap/ic_launcher\"")
        set(_icon_flat "${_work}/compiled/mipmap_ic_launcher.png.flat")
        add_custom_command(OUTPUT "${_icon_flat}"
            COMMAND ${CMAKE_COMMAND} -E make_directory "${_work}/res/mipmap" "${_work}/compiled"
            COMMAND ${CMAKE_COMMAND} -E copy "${APK_ICON}" "${_work}/res/mipmap/ic_launcher.png"
            COMMAND "${_tools}/aapt2" compile -o "${_work}/compiled" "${_work}/res/mipmap/ic_launcher.png"
            DEPENDS "${APK_ICON}"
            COMMENT "Compiling the launcher icon"
            VERBATIM
        )
    endif()
    configure_file("${CMAKE_CURRENT_FUNCTION_LIST_DIR}/android/AndroidManifest.xml.in" "${_work}/AndroidManifest.xml" @ONLY)

    fried_imported_dir("${APK_ENGINE_ASSETS}" _engine_copy)
    fried_imported_dir("${APK_GAME_ASSETS}" _game_copy)
    file(GLOB_RECURSE _asset_sources CONFIGURE_DEPENDS "${APK_ENGINE_ASSETS}/*" "${APK_GAME_ASSETS}/*")

    add_custom_command(OUTPUT "${_apk}"
        COMMAND ${CMAKE_COMMAND} -E rm -rf "${_work}/assets" "${_work}/payload"
        COMMAND ${CMAKE_COMMAND} -E copy_directory "${_engine_copy}" "${_work}/assets/engine"
        COMMAND ${CMAKE_COMMAND} -E copy_directory "${_game_copy}" "${_work}/assets/game"
        COMMAND ${CMAKE_COMMAND} -E make_directory "${_work}/payload/lib/${ANDROID_ABI}"
        COMMAND ${CMAKE_COMMAND} -E copy "$<TARGET_FILE:${target_name}>" "${_work}/payload/lib/${ANDROID_ABI}/libmain.so"
        COMMAND ${CMAKE_COMMAND} -E copy "${_work}/dex/classes.dex" "${_work}/payload/classes.dex"
        COMMAND "${_tools}/aapt2" link -o "${_work}/unaligned.apk" -I "${_fried_android_jar}"
            --manifest "${_work}/AndroidManifest.xml"
            --min-sdk-version ${FRIED_ANDROID_MIN_API} --target-sdk-version ${FRIED_ANDROID_TARGET_API}
            --version-code ${APK_VERSION_CODE} --version-name ${APK_VERSION}
            -A "${_work}/assets" ${_icon_flat}
        COMMAND "${FRIED_JAR}" -u0Mf "${_work}/unaligned.apk" -C "${_work}/payload" .
        COMMAND "${_tools}/zipalign" -f -P 16 4 "${_work}/unaligned.apk" "${_work}/aligned.apk"
        COMMAND "${FRIED_JAVA}" -jar "${_tools}/lib/apksigner.jar" sign
            --ks "${FRIED_ANDROID_KEYSTORE}" --ks-pass pass:android --key-pass pass:android --ks-key-alias androiddebugkey
            --out "${_apk}" "${_work}/aligned.apk"
        DEPENDS ${target_name} "${_work}/dex/classes.dex" ${_icon_flat} "${_work}/AndroidManifest.xml" ${_asset_sources}
        COMMENT "Packaging ${target_name}.apk"
        VERBATIM
    )
    add_custom_target(${target_name}_apk ALL DEPENDS "${_apk}")
    fried_depend_on_import(${target_name}_apk)
endfunction()
