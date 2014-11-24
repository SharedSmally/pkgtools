# makefile to generate application
# 
#NAME=app
#include make.app
#
#sources are under PKG_HOME/appsrc
# main.cc
# App.h/App.cc
#

APP_NAME=
main:app
	
app:main.cc ${APP_NAME}.h ${APP_NAME}.cc
	${CXX} -o ${name} main.cc ${APP_NAME}.cc ${OBJS} \
	${CPPFLAGS} ${CXXFLAGS} ${LDFLAGS} ${LDLIBS} ${APP_LIBS}
	
	