
include(GNUInstallDirs)

define_property(TARGET PROPERTY "INTERFACE_DESCRIPTION"
  BRIEF_DOCS "Description of the target"
  FULL_DOCS "Description of the target"
)

define_property(TARGET PROPERTY "INTERFACE_URL"
  BRIEF_DOCS "An URL where people can get more information about and download the package."
  FULL_DOCS "An URL where people can get more information about and download the package."
)

define_property(TARGET PROPERTY "INTERFACE_PKG_CONFIG_REQUIRES"
  BRIEF_DOCS "A list of packages required by this package. The versions of these packages may be specified using the comparison operators =, <, >, <= or >=."
  FULL_DOCS "A list of packages required by this package. The versions of these packages may be specified using the comparison operators =, <, >, <= or >=."
)



#[=[

CAUTION THIS IS DEAD CODE 

function(bcm_generate_pkgconfig_file)
    set(options)
    set(oneValueArgs NAME LIB_DIR INCLUDE_DIR DESCRIPTION)
    set(multiValueArgs TARGETS CFLAGS LIBS REQUIRES)

    cmake_parse_arguments(PARSE "${options}" "${oneValueArgs}" "${multiValueArgs}" ${ARGN})

    set(LIB_DIR ${CMAKE_INSTALL_LIBDIR})
    if(PARSE_LIB_DIR)
        set(LIB_DIR ${PARSE_LIB_DIR})
    endif()
    set(INCLUDE_DIR ${CMAKE_INSTALL_INCLUDEDIR})
    if(PARSE_INCLUDE_DIR)
        set(INCLUDE_DIR ${PARSE_INCLUDE_DIR})
    endif()

    set(LIBS)
    set(DESCRIPTION "No description")
    if(PARSE_DESCRIPTION)
        set(DESCRIPTION ${PARSE_DESCRIPTION})
    endif()

    foreach(TARGET ${PARSE_TARGETS})
        get_property(TARGET_NAME TARGET ${TARGET} PROPERTY NAME)
        get_property(TARGET_TYPE TARGET ${TARGET} PROPERTY TYPE)
        if(NOT TARGET_TYPE STREQUAL "INTERFACE_LIBRARY")
            set(LIBS "${LIBS} -l${TARGET_NAME}")
        endif()
    endforeach()

    if(LIBS OR PARSE_LIBS)
        set(LIBS "Libs: -L\${libdir} ${LIBS} ${PARSE_LIBS}")
    endif()

    set(PKG_NAME ${PROJECT_NAME})
    if(PARSE_NAME)
        set(PKG_NAME ${PARSE_NAME})
    endif()

    file(WRITE ${PKGCONFIG_FILENAME}
"
prefix=${CMAKE_INSTALL_PREFIX}
exec_prefix=\${prefix}
libdir=\${exec_prefix}/${LIB_DIR}
includedir=\${exec_prefix}/${INCLUDE_DIR}
Name: ${PKG_NAME}
Description: ${DESCRIPTION}
Version: ${PROJECT_VERSION}
Cflags: -I\${includedir} ${PARSE_CFLAGS}
${LIBS}
Requires: ${PARSE_REQUIRES}
"
  )

endfunction()

#]=]



#[=[
bcm_preprocess_pkgconfig_property
-----------------------------------

Progressive string replacements applied to a target property

1. keep INSTALL_INTERFACE and scrub BUILD_INTERFACE via CMake generator expressions
2. translate CMake argot into pkg-config variables includedir,libdir and prefix

#]=]

function(bcm_preprocess_pkgconfig_property VAR TARGET PROP)

    get_target_property(OUT_PROP ${TARGET} ${PROP})

    #if(PC_VERBOSE)
    #message( STATUS "[bcm_preprocess_pkgconfig_property PROP:${PROP} OUT_PROP:${OUT_PROP} ")
    #endif()

    string(REPLACE "$<BUILD_INTERFACE:" "$<0:" OUT_PROP "${OUT_PROP}")
    string(REPLACE "$<INSTALL_INTERFACE:" "$<1:" OUT_PROP "${OUT_PROP}")

    string(REPLACE "$<INSTALL_PREFIX>/${CMAKE_INSTALL_INCLUDEDIR}" "\${includedir}" OUT_PROP "${OUT_PROP}")
    string(REPLACE "$<INSTALL_PREFIX>/${CMAKE_INSTALL_LIBDIR}" "\${libdir}" OUT_PROP "${OUT_PROP}")
    string(REPLACE "$<INSTALL_PREFIX>" "\${prefix}" OUT_PROP "${OUT_PROP}")

    set(${VAR} ${OUT_PROP} PARENT_SCOPE)

    #if(PC_VERBOSE)
    #message( STATUS "]bcm_preprocess_pkgconfig_property PROP:${PROP} OUT_PROP:${OUT_PROP} ")
    #endif()

endfunction()



#[=[
bcm_auto_pkgconfig_each
-----------------------------------

Translate properties from a CMake target into variables 
and write them to a pkg-config pc file 

Relevant target properties:

INTERFACE_LINK_LIBRARIES
    crucial way to access the list of targets that the argument target depends on 

INTERFACE_PKG_CONFIG_NAME
    dependent target property used for pc names

INTERFACE_PKG_CONFIG_REQUIRES 
    typically not used, but rather this is auto obtained from the targets that 
    this target depends on

The pkg-config pc name for the argument target comes from the lowercased 
project name.

#]=]


function(bcm_list_difference outvar l1 l2) 
    # Create list outvar with elements from l1 that are not in l2
    set(tmp)
    foreach( l ${l1} ) 
      if( NOT ${l} IN_LIST l2 )
        list(APPEND tmp ${l}) 
      endif()
    endforeach()
    set(${outvar} ${tmp} PARENT_SCOPE)
endfunction()

function(bcm_list_difference_test)
    set(l1 A B C)
    set(l2 A C Z)
    message(STATUS "l1:${l1}")
    message(STATUS "l2:${l2}")
    bcm_list_difference(l1ml2  "${l1}" "${l2}")
    message(STATUS "l1ml2:${l1ml2}")
endfunction()


function(bcm_auto_pkgconfig_each)
    set(options)
    set(oneValueArgs NAME TARGET)
    set(multiValueArgs)

    cmake_parse_arguments(PARSE "${options}" "${oneValueArgs}" "${multiValueArgs}" ${ARGN})

    set(LIBS)
    set(CFLAGS)
    set(REQUIRES)
    set(DESCRIPTION "No description")

    string(TOLOWER ${PROJECT_NAME} PROJECT_NAME_LOWER)
    set(PACKAGE_NAME ${PROJECT_NAME})

    set(TARGET)
    if(PARSE_TARGET)
        set(TARGET ${PARSE_TARGET})
    else()
        message(SEND_ERROR "Target is required for auto pkg config")
    endif()

    if(PARSE_NAME)
        set(PACKAGE_NAME ${PARSE_NAME})
    endif()

    string(TOUPPER ${PACKAGE_NAME} PACKAGE_NAME_UPPER)
    string(TOLOWER ${PACKAGE_NAME} PACKAGE_NAME_LOWER)

    get_property(TARGET_NAME TARGET ${TARGET} PROPERTY NAME)
    get_property(TARGET_TYPE TARGET ${TARGET} PROPERTY TYPE)
    get_property(TARGET_DESCRIPTION TARGET ${TARGET} PROPERTY INTERFACE_DESCRIPTION)
    get_property(TARGET_URL TARGET ${TARGET} PROPERTY INTERFACE_URL)
    get_property(TARGET_REQUIRES TARGET ${TARGET} PROPERTY INTERFACE_PKG_CONFIG_REQUIRES)
    get_property(TARGET_LINK_LIBS TARGET ${TARGET} PROPERTY INTERFACE_LINK_LIBRARIES)

    get_property(TARGET_ILL TARGET ${TARGET} PROPERTY INTERFACE_LINK_LIBRARIES)
    get_property(TARGET_LL TARGET ${TARGET} PROPERTY LINK_LIBRARIES)
    get_property(TARGET_ILDL TARGET ${TARGET} PROPERTY IMPORTED_LINK_DEPENDENT_LIBRARIES)

    bcm_list_difference(TARGET_PRIVLIB "${TARGET_LL}" "${TARGET_ILL}")

    if(NOT TARGET_TYPE STREQUAL "INTERFACE_LIBRARY")
        set(LIBS "${LIBS} -l${TARGET_NAME}")
    endif()

    if(PC_VERBOSE)
    message(STATUS "bcm_auto_pkgconfig_each LIBS:${LIBS}  TARGET_NAME:${TARGET_NAME} TARGET_TYPE:${TARGET_TYPE} " )
    message(STATUS "bcm_auto_pkgconfig_each TARGET_ILL :${TARGET_ILL} " )
    message(STATUS "bcm_auto_pkgconfig_each TARGET_LL  :${TARGET_LL} " )
    message(STATUS "bcm_auto_pkgconfig_each TARGET_ILDL:${TARGET_ILDL} " )
    message(STATUS "bcm_auto_pkgconfig_each TARGET_PRIVLIB:${TARGET_PRIVLIB} " )
    endif()
 

    if(TARGET_REQUIRES)
        list(APPEND REQUIRES ${TARGET_REQUIRES})
        if(PC_VERBOSE)
        message(STATUS "bcm_auto_pkgconfig_each TARGET_REQUIRES:${TARGET_REQUIRES} " )
        endif()
    endif()
   
    set(LINK_LIBS)
    if(TARGET_LINK_LIBS)
        bcm_preprocess_pkgconfig_property(LINK_LIBS ${TARGET} INTERFACE_LINK_LIBRARIES)
    endif()

    if(PC_VERBOSE)
    message(STATUS "bcm_auto_pkgconfig_each LINK_LIBS:${LINK_LIBS} " )
    endif()

#[=[

#]=]     

    foreach(LIB ${LINK_LIBS})
        if(TARGET ${LIB})
            get_property(LIB_PKGCONFIG_NAME TARGET ${LIB} PROPERTY INTERFACE_PKG_CONFIG_NAME)

            if(PC_VERBOSE)
            message(STATUS "bcm_auto_pkgconfig_each LIB_PKGCONFIG_NAME:${LIB_PKGCONFIG_NAME} " )
            endif()

            # TODO: Error if this property is missing
            if(LIB_PKGCONFIG_NAME)
                list(APPEND REQUIRES ${LIB_PKGCONFIG_NAME})
                if(PC_VERBOSE)
                message(STATUS "bcm_auto_pkgconfig_each LIB:${LIB} : appending REQUIRES:${REQUIRES}" )
                endif()
            else()
                message(STATUS "bcm_auto_pkgconfig_each LIB:${LIB} : MISSING LIB_PKGCONFIG_NAME " ) 
            endif()
        else()
            if("${LIB}" MATCHES "::")
                set(LIB_TARGET_NAME "$<TARGET_PROPERTY:${LIB},ALIASED_TARGET>")
            else()
                set(LIB_TARGET_NAME "${LIB}")
            endif()

            bcm_shadow_exists(HAS_LIB_TARGET ${LIB})
            list(APPEND REQUIRES "$<${HAS_LIB_TARGET}:$<TARGET_PROPERTY:${LIB_TARGET_NAME},INTERFACE_PKG_CONFIG_NAME>>")

            #[=[
            When the lib starts with a slash indicating an absolute path or starts with "-" suggesting 
            an already formatted "-l" the LLIB just takes asis, otherwise the "-l" prefixing is added 
            #]=]

            if("${LIB}" MATCHES "^[-/]")
                 set(LLIB ${LIB})
                 if(PC_VERBOSE)
                 message(STATUS "bcm_auto_pkgconfig_each LIB MATCH      LLIB : ${LLIB} ")
                 endif()
            else()
                 set(LLIB "-l${LIB}")
                 if(PC_VERBOSE)
                 message(STATUS "bcm_auto_pkgconfig_each LIB NO-MATCH   LLIB : ${LLIB} ")
                 endif()
            endif()

            set(LIBS "${LIBS} $<$<NOT:${HAS_LIB_TARGET}>:${LLIB}>")

            if(PC_VERBOSE)
            message(STATUS "bcm_auto_pkgconfig_each NON-TARGET LIB:${LIB} LIB_TARGET_NAME:${LIB_TARGET_NAME} LIBS:${LIBS} " )
            endif()
        endif()
    endforeach()

    # cannot filter exclude REQUIRES to remove blanks here as they are great big generator expressions
    if(PC_VERBOSE)
    message(STATUS "bcm_auto_pkgconfig_each REQUIRES:${REQUIRES} LIBS:${LIBS} " )
    endif()


    bcm_preprocess_pkgconfig_property(INCLUDE_DIRS ${TARGET} INTERFACE_INCLUDE_DIRECTORIES)
    if(INCLUDE_DIRS)
        set(CFLAGS "${CFLAGS} $<$<BOOL:${INCLUDE_DIRS}>:-I$<JOIN:${INCLUDE_DIRS}, -I>>")
    endif()

    bcm_preprocess_pkgconfig_property(COMPILE_DEFS ${TARGET} INTERFACE_COMPILE_DEFINITIONS)
    if(COMPILE_DEFS)
        set(CFLAGS "${CFLAGS} $<$<BOOL:${COMPILE_DEFS}>:-D$<JOIN:${COMPILE_DEFS}, -D>>")
    endif()

    bcm_preprocess_pkgconfig_property(COMPILE_OPTS ${TARGET} INTERFACE_COMPILE_OPTIONS)
    if(COMPILE_OPTS)
        set(CFLAGS "${CFLAGS} $<$<BOOL:${COMPILE_OPTS}>:$<JOIN:${COMPILE_OPTS}, >>")
    endif()

    set(CONTENT)

    if(TARGET_DESCRIPTION)
        set(DESCRIPTION "${TARGET_DESCRIPTION}")
    endif()

    if(TARGET_URL)
        set(CONTENT "${CONTENT}\nUrl: ${TARGET_URL}")
    endif()

    if(CFLAGS)
        set(CONTENT "${CONTENT}\nCflags: ${CFLAGS}")
    endif()

    if(LIBS)
        #set(CONTENT "${CONTENT}\n$<$<BOOL:${LIBS}>:Libs: -L\${libdir} ${LIBS}>")
        set(CONTENT "${CONTENT}\nLibs: -L\${libdir} ${LIBS}")
    else()
        if(PC_VERBOSE)
        message(STATUS "bcm_auto_pkgconfig_each.NO-LIBS" ) 
        endif()
    endif()

    if(REQUIRES)
        # collapse the genex and then filter empties : avoids confusing pkg-config
        list(TRANSFORM REQUIRES GENEX_STRIP) 
        list(FILTER REQUIRES EXCLUDE REGEX "^$")
        string(REPLACE ";" "," REQUIRES_CONTENT "${REQUIRES}")

        if(PC_VERBOSE)
        message(STATUS "bcm_auto_pkgconfig_each.REQUIRES_CONTENT ${REQUIRES_CONTENT}" ) 
        endif()

        set(CONTENT "${CONTENT}\nRequires: ${REQUIRES_CONTENT}")
    endif()

    if(PC_VERBOSE)
    message(STATUS "bcm_auto_pkgconfig_each.CONTENT ${CONTENT}" ) 
    endif()

    # formerly wrote ${PACKAGE_NAME_LOWER}.pc


    set(PC_STEM ${PACKAGE_NAME})
    if(PC_VERBOSE)
    message(STATUS "bcm_auto_pkgconfig_each generate PC_STEM:${PC_STEM} " )
    endif()


    file(GENERATE OUTPUT ${CMAKE_CURRENT_BINARY_DIR}/${PC_STEM}.pc CONTENT
"

# bcm_auto_pkgconfig_each

prefix=${CMAKE_INSTALL_PREFIX}
exec_prefix=\${prefix}
libdir=\${exec_prefix}/${CMAKE_INSTALL_LIBDIR}
includedir=\${exec_prefix}/${CMAKE_INSTALL_INCLUDEDIR}
Name: ${PACKAGE_NAME_LOWER}
Description: ${DESCRIPTION}
Version: ${PROJECT_VERSION}
${CONTENT}
"
  )
    install(FILES ${CMAKE_CURRENT_BINARY_DIR}/${PC_STEM}.pc DESTINATION ${CMAKE_INSTALL_LIBDIR}/pkgconfig)
    set_property(TARGET ${TARGET} PROPERTY INTERFACE_PKG_CONFIG_NAME ${PC_STEM})
endfunction()

function(bcm_auto_pkgconfig)
    set(options)
    set(oneValueArgs NAME)
    set(multiValueArgs TARGET) # TODO: Rename to TARGETS

    cmake_parse_arguments(PARSE "${options}" "${oneValueArgs}" "${multiValueArgs}" ${ARGN})


    list(LENGTH PARSE_TARGET TARGET_COUNT)

    if(PC_VERBOSE)
    message(STATUS "bcm_auto_pkgconfig PARSE_TARGET:${PARSE_TARGET} TARGET_COUNT:${TARGET_COUNT} PARSE_NAME:${PARSE_NAME} ")
    endif()

#[=[  
TARGET_COUNT 1 without PARSE_NAME is normal in Opticks usage where the invokation 
is of the form::

    bcm_deploy(TARGETS ${name} NAMESPACE Opticks:: SKIP_HEADER_INSTALL TOPMATTER  "...")

#]=]
   
    if(TARGET_COUNT EQUAL 1)  
        bcm_auto_pkgconfig_each(TARGET ${PARSE_TARGET} NAME ${PARSE_NAME})
    else()
        string(TOLOWER ${PROJECT_NAME} PROJECT_NAME_LOWER)
        set(PACKAGE_NAME ${PROJECT_NAME})

        if(PARSE_NAME)
            set(PACKAGE_NAME ${PARSE_NAME})
        endif()

        string(TOLOWER ${PACKAGE_NAME} PACKAGE_NAME_LOWER)

        set(GENERATE_PROJECT_PC On)
        foreach(TARGET ${PARSE_TARGET})
            if("${TARGET}" STREQUAL "${PACKAGE_NAME_LOWER}")
                set(GENERATE_PROJECT_PC Off)
            endif()
            bcm_auto_pkgconfig_each(TARGET ${TARGET} NAME ${TARGET})
        endforeach()

        string(REPLACE ";" "," REQUIRES "${PARSE_TARGET}")
        # TODO: Get description from project
        set(DESCRIPTION "No description")

        if(GENERATE_PROJECT_PC)

            if(PC_VERBOSE)
            message(STATUS "bcm_auto_pkgconfig.GENERATE_PROJECT_PC ")  # have not observed this 
            endif()

            file(GENERATE OUTPUT ${CMAKE_CURRENT_BINARY_DIR}/${PACKAGE_NAME_LOWER}.pc CONTENT
"
Name: ${PACKAGE_NAME_LOWER}
Description: ${DESCRIPTION}
Version: ${PROJECT_VERSION}
Requires: ${REQUIRES}
"
            )
        endif()
    endif()


endfunction()
