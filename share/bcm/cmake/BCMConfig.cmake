

set(BCM_MODULE "${CMAKE_CURRENT_LIST_FILE}")
if(BCM_VERBOSE)
   message(STATUS "BCM_MODULE:${BCM_MODULE}")
endif()


list(APPEND CMAKE_MODULE_PATH ${CMAKE_CURRENT_LIST_DIR})
include(BCMFuture)
enable_testing()

function(find_subdirectories INPUT_DIRECTORY SUBMODULE_HEADER)
    file(GLOB_RECURSE LIBS ${INPUT_DIRECTORY}/*CMakeLists.txt)
    foreach(lib ${LIBS})
        file(READ ${lib} CONTENT)
        if("${CONTENT}" MATCHES ${SUBMODULE_HEADER})
            get_filename_component(LIB_DIR ${lib} DIRECTORY)
            get_filename_component(LIB_NAME ${LIB_DIR} NAME)
            if(NOT "${LIB_NAME}" IN_LIST EXCLUDE_LIBS)
                add_subdirectory(${LIB_DIR})
            endif()
        endif()
    endforeach()
endfunction()

function(workspace WORKSPACE_NAME)
    set(options)
    set(oneValueArgs DESCRIPTION VERSION)
    set(multiValueArgs LANGUAGES)

    cmake_parse_arguments(PARSE "${options}" "${oneValueArgs}" "${multiValueArgs}" ${ARGN})

    if(PARSE_UNPARSED_ARGUMENTS)
        message(FATAL_ERROR "Unknown keywords given to workspace(): \"${PARSE_UNPARSED_ARGUMENTS}\"")
    endif()

    project(${WORKSPACE_NAME} ${PARSE_VERSION} ${PARSE_DESCRIPTION} ${PARSE_LANGUAGES})
    set(CMAKE_WORKSPACE_NAME ${WORKSPACE_NAME} PARENT_SCOPE)
    string(TOUPPER ${WORKSPACE_NAME} UPPER_WORKSPACE_NAME)
    set(CMAKE_UPPER_WORKSPACE_NAME ${UPPER_WORKSPACE_NAME} PARENT_SCOPE)
endfunction()
